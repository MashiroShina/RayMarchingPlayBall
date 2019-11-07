Shader "Hidden/RayMarchingBall"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        // No culling or depth
        Cull Off ZWrite Off ZTest Always

        Pass
        {
            CGPROGRAM
// Upgrade NOTE: excluded shader from DX11, OpenGL ES 2.0 because it uses unsized arrays
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 5.0
            
            #include "UnityCG.cginc"
            #include "DistanceFunctions.cginc"
            
            sampler2D _MainTex;
            //Setup
            uniform sampler2D _CameraDepthTexture;
            uniform float4x4 _CamFrustum,_CamToWorld;
            uniform int _MaxIterations;
            uniform float _Accuracy;
            uniform float _maxDistance;
            //Light
            uniform float3 _LightDir,_LightCol;
            uniform float _LightIntensity;
            //Color
            uniform fixed4 _GroundColor;
            uniform float _ColorIntensity;
            //Shadow
            uniform float2 _ShadowDistance;
            uniform float _ShadowIntensity,_ShadowPenumbra;
			//AO
            uniform float _AoStepSize,_AoIntensity;
            uniform int _AoIterations;
            //Reflection
			samplerCUBE _ReflectionCube;
            uniform int _ReflectionCount;
            uniform float _ReflectionIntensity;
            uniform float _EnvRefIntensity;
            //sphere
			uniform float4 _spheres[100];
			uniform int _sphereNum;
            uniform float4 _sphereRigi[100];
			uniform int _sphereRigiNum;
            uniform float _sphereSmooth;
            uniform float3 _sphereColor;

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 ray :TEXCOORD1;
            };

			struct Ray
			{
				float3 origin;
				float3 direction;
			};

			 struct RayHit
			{
				float4 position;
				float3 normal;
				float3 color;
			};

			Ray createRay(float3 origin,float3 direction)
			{
				Ray ray;
				ray.origin=origin;
				ray.direction=direction;
				return ray;
			}

			 RayHit CreateRayHit()
			{
				RayHit hit;
				hit.position = float4(0.0f, 0.0f, 0.0f,0.0f);
				hit.normal = float3(0.0f, 0.0f, 0.0f);
				hit.color = float3(0.0f, 0.0f, 0.0f);
				return hit;
			}

            v2f vert (appdata v)
            {
                v2f o;
                half index = v.vertex.z;
                v.vertex.z=0;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                
                o.ray=_CamFrustum[(int)index].xyz;
                o.ray/=abs(o.ray.z);//z=-1
                o.ray=mul(_CamToWorld,o.ray);
                
                return o;
            }

            float4 distenceField(float3 p)
            {	
				float4 combines;
				combines=float4(_sphereColor.rgb, sdSphere(p-_spheres[0].xyz,_spheres[0].w));
				for(int i=1; i<_sphereNum; i++)
                {
                    float4 sphereAdd=float4(_sphereColor.rgb, sdSphere(p-_spheres[i].xyz,_spheres[i].w));
                    combines = opUS(combines,sphereAdd,_sphereSmooth);//opUS
                }
				float4 sphere=float4(_sphereColor.rgb, sdSphere(p-_sphereRigi[0].xyz,_sphereRigi[0].w));
				for(int i=1; i<_sphereRigiNum; i++)
                {
                    float4 sphereAdd2=float4(_sphereColor.rgb, sdSphere(p-_sphereRigi[i].xyz,_sphereRigi[i].w));
                    sphere = opUS(sphere,sphereAdd2,_sphereSmooth);//opUS
                }
				combines = opUS(combines,sphere,_sphereSmooth);//opUS
				combines=opUS(combines,float4(_GroundColor.rgb,sdPlane(p,float4(0,1,0,0))),_sphereSmooth);
				return combines;
            }
            
            float3 getNormal(float3 p)
            {
                const float2 offset = float2(0.001f,0.0f);
                float3 n= float3(
                    distenceField(p+offset.xyy).w-distenceField(p-offset.xyy).w,
                    distenceField(p+offset.yxy).w-distenceField(p-offset.yxy).w,
                    distenceField(p+offset.yyx).w-distenceField(p-offset.yyx).w
                );
                return normalize(n);
            }
            
            float hardShadow(float3 ro,float3 rd,float mint,float maxt)
            {
                for(float t=mint; t<maxt;)
                {
                    float h = distenceField(ro+rd*t).w;
                    if(h<0.001)
                    {
                        return 0.0;
                    }
                    t+=h;
                }
                return 1.0;
            }
            
            float softShadow(float3 ro,float3 rd,float mint,float maxt,float k)
            {
                float result=1.0;
                for(float t=mint; t<maxt;)
                {
                    float h=distenceField(ro+rd*t).w;
                    if(h<0.001)
                    {
                        return 0.0;
                    }
                    result = min(result,k*h/t);
                    t+=h;
                }
                return result;
            }

            float AmbientOcclusion(float3 p,float3 n)
            {
                float step=_AoStepSize;
                float ao = 0.0;
                float dist;
                for(int i=0;i<_AoIterations;i++)
                {
                    dist= step*i;
                    ao+= max(0.0f,(dist-distenceField(p+n*dist).w)/dist);
                }
                return (1.0f-ao*_AoIntensity);
            }
              RayHit raymarching(Ray ray,float depth,int MaxIterations,int maxDistance,int atten);
			      float3 Shading(inout Ray ray,RayHit hit,float3 col);
				  
			float nrand(float2 uv)
			{
				return frac(sin(dot(uv, float2(12.9898, 78.233))) * 43758.5453);
			}
			float3 normalAt(float3 p)
			{
			   float dist=distenceField(p).w;
			   float2 epsilon=float2(0.001,0.0);
			   return normalize(float3(dist-distenceField(p-epsilon.xyy).w, 
									 dist-distenceField(p-epsilon.yxy).w,
									 dist-distenceField(p-epsilon.yyx).w));
			}

			float3 shadTransparent( inout Ray ray,inout RayHit hit, in float3 col)
			{
				float3 oriCol = col;
				float3 col2=col;
				float3 pos = hit.position.xyz;
				float3 rd = ray.direction;
				float3 nor = hit.normal;//*nrand(col.xy);
				float fre=clamp(1.0+dot(rd,nor),0.0,1.0);
				float3  hal = normalize( _LightDir-rd );
				float3  ref = reflect( -rd, nor );
				float spe1 = clamp( dot(nor,hal), 0.0, 1.0 );
				float spe2 = clamp( dot(ref,_LightDir), 0.0, 1.0 );

				float ds = 1.6 - col.y;

				col += ds*1.5*float3(1.0,0.9,0.8)*pow( spe1, 80.0 );
				col += ds*0.2*float3(0.9,1.0,1.0)*smoothstep(0.4,0.8,fre);
				col += ds*0.9*float3(0.6,0.7,1.0)*smoothstep( -0.5, 0.5, -reflect( rd, nor ).y )*smoothstep(0.2,0.4,fre);    
				col += ds*0.5*float3(1.0,0.9,0.8)*pow( spe2, 80.0 );
				col += ds*0.5*float3(1.0,0.9,0.8)*pow( spe2, 16.0 );
				
//				float3 rg = tex2Dlod( _MainTex,float4(col,0)).xyz;
//				col+=rg;
				ray.direction = normalize(reflect(ray.direction,hit.normal));
				ray.origin= hit.position.xyz + (ray.direction * 0.1);
				
				// hide aliasing a bit temp+result
				float3 temp= lerp( col, oriCol, smoothstep(0.6,1.0,fre));
				return  temp; 
			}

            float3 Shading(inout Ray ray,RayHit hit,float3 col)
            {
                float3 light =(_LightCol* dot(-_LightDir,hit.normal) * 0.5+0.5)*_LightIntensity;
                
		        float shadow=softShadow(hit.position.xyz,-_LightDir,0.1,_ShadowDistance.y,_ShadowPenumbra)*0.5+0.5;
                shadow = max(0.0,pow(shadow,_ShadowIntensity));
                float ao=AmbientOcclusion(hit.position.xyz,hit.normal); 
                return float3(hit.color*light*shadTransparent(ray,hit,col))*shadow*ao;                
            }

            RayHit raymarching(Ray ray,float depth,int MaxIterations,int maxDistance,int atten)
            {
				RayHit bestHit = CreateRayHit();
                float t=0;
                for(int i=0;i<MaxIterations;i++)
                {
                    if(t>maxDistance||t>=depth)
                    {
						 bestHit.position = float4(0,0,0,0);
                        break;
                    }
                    
                    float3 p = ray.origin + ray.direction*t;
                    float4 d = distenceField(p);
                    
                    if(d.w < _Accuracy)
                    {
						bestHit.position = float4(p,1);
						bestHit.normal = getNormal(p);
						bestHit.color = d.rgb/atten;
                        break;
                    }
                    t+=d.w;
                }
                return bestHit;
            }
            
            fixed4 frag (v2f i) : SV_Target
            {
                float depth = LinearEyeDepth(tex2D(_CameraDepthTexture,i.uv).r);
                depth *= length(i.ray.xyz);
                fixed3 col = tex2D(_MainTex,i.uv);
				Ray ray=createRay(_WorldSpaceCameraPos,normalize(i.ray.xyz));
				RayHit hit;
                fixed4 result; 
                hit = raymarching( ray,depth,_MaxIterations,_maxDistance,1);
                if(hit.position.w==1)
                {
                    float3 s=Shading(ray,hit,col);//setcolor
                    result = fixed4(s,1);
                    result += fixed4(texCUBE(_ReflectionCube,hit.normal).rgb*_EnvRefIntensity*_ReflectionIntensity,0);
					for(int i=1;i<_ReflectionCount;i++)
					{
						hit = raymarching( ray,_maxDistance,_MaxIterations*i,_maxDistance/i,i*i);
						if(hit.position.w==1)
                        {
							float3 s=Shading(ray,hit,col);//setcolor
                            result += fixed4(s*_ReflectionIntensity,0);
						}
						else
						{
						break;
						}
					}
                }else
                {
                    result = fixed4(0,0,0,0);
                }
                return fixed4(col*(1.0-result.w)+result.xyz*result.w,1.0);
            }
            ENDCG
        }
    }
}
