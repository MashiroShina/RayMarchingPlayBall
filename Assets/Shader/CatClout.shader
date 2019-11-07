Shader "Custom/CatCloud"
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
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 5.0
            
            #include "UnityCG.cginc"
            #include "SDF.cginc"
            #include "FBM.cginc"
             
            sampler2D _MainTex;
            //Setup
            uniform sampler2D _CameraDepthTexture;
            uniform float4x4 _CamFrustum,_CamToWorld;
            uniform float3 _LightDir;
            uniform sampler2D _ns;
			uniform float4 _CloudAndSphere,_Cloud2;
			
			uniform float4 _cloudRigi[100];
			uniform int _cloudRigiNum;
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
			float density(float3 pos, float dist)
			{    
				float den = -0.2 - dist * 1.5 + 3.0 * fractal_noise(pos);
				den = clamp(den, 0.0, 1.0);
				float size = clamp(tex2Dlod(_NoiseTex, 0.5* 2.0 + 0.1), 0.4, 0.8);
				float edge = 1.0 - smoothstep(size*_CloudAndSphere.w, _CloudAndSphere.w, dist);
				edge *= edge;
				den *= edge;
				return den*1.5;
			}
            
			 float distenceField(float3 p)
            {	
				float combines;
				combines=sdSphere(p-_cloudRigi[0].xyz,_cloudRigi[0].w);
				for(int i=0; i<_cloudRigiNum; i++)
                {
                    float cloudAdd=sdSphere(p-_cloudRigi[i].xyz,_cloudRigi[i].w);
                    combines = opIS(combines,cloudAdd,-0.5);//opUS
                }
				return combines;
            }

			float3 color(float den, float dist)
			{
				// add animation
				float3 result = lerp(float3(1.0, 0.9, 0.8 + sin(_Time.y) * 0.1), 
								  float3(0.5, 0.15, 0.1 + sin(_Time.y) * 0.1), den * den);
    
				float3 colBot = 3.0 * float3(1.0, 0.9, 0.5);
				float3 colTop = 2.0 * float3(0.5, 0.55, 0.55);
				result *= lerp(colBot, colTop, min((dist+0.5)/4, 1.0));
				
				return float3(1,1,1);//result
			}
		   float3 raymarchingCloud(float3 ro, float3 rd, float t,float3 backCol,float depth,float3 cloudPos);
           float4 raymarching(Ray ray,float3 backCol,float depth)
            {
                RayHit bestHit = CreateRayHit();
				float4 result;
                float t=0;
                for(int i=0;i<64;i++)
                {
                    if(t>20||t>=depth)
                    {
						bestHit.position = float4(0,0,0,0);
						result=float4(backCol,0);
                        break;
                    }
                    
                    float3 p = ray.origin + ray.direction*t;
                    float d = distenceField(p);
                    
                    if(d <0.01)//限定范围 只能在球里面产生烟雾
                    {
						bestHit.position.w=1;
						result = float4(raymarchingCloud(p,ray.direction,d,backCol,depth,_CloudAndSphere.xyz),bestHit.position.w);             
                        break;
                    }
                    t+=d;
                }
				return result;
            }
           
		   float3 raymarchingCloud(float3 ro, float3 rd, float t,float3 backCol,float depth,float3 cloudPos)
			{
				float4 sum = float4(0.0,0.0,0.0,0.0);
				float3 pos = ro + rd * t;
				for (int i = 0; i < 30; i++) {
					float dist = length(pos -_cloudRigi[0]);
                    for(int i=0; i<_cloudRigiNum; i++)
                    {
                        float cloudAdd=length(pos-_cloudRigi[i].xyz);
                        dist = opIS(dist,cloudAdd,-0.5);
                    }
					if (dist > _CloudAndSphere.w + 0.01 || sum.a > 0.99 || t>depth ) break;
					float den = density(pos, dist);
					float4 col = float4(color(den, dist), den);
					col.rgb *= col.a;
					sum = sum + col*(1.0 - sum.a); 
					t += max(0.05, 0.02 * t);
					pos = ro + rd * t;
				}
    
				sum = clamp(sum, 0.0, 1.0);
				backCol = lerp(backCol, sum.xyz, sum.a);
				return backCol;
			}
            fixed4 frag (v2f i) : SV_Target
            {
                float depth = LinearEyeDepth(tex2D(_CameraDepthTexture,i.uv).r);
                depth *= length(i.ray.xyz); 
                fixed4 sceneCol = tex2D(_MainTex,i.uv);
                fixed4 ns = tex2D(_ns,i.uv);
                fixed4 col = fixed4(0.0,0.0,0.0,0.0);  
				Ray ray=createRay(_WorldSpaceCameraPos,normalize(i.ray.xyz));
                col = raymarching(ray,sceneCol.xyz,depth);
                return col;
            }
            ENDCG
        }
    }
}
