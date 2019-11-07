#define HASHSCALE3 float3(.1031, .1030, .0973)

sampler2D _NoiseTex;
float noise( in float3 x )
{
    float3 p = floor(x);
    float3 f = frac(x);
	f = f*f*(3.0-2.0*f);
	float2 uv = (p.xy+float2(37.0,17.0)*p.z) + f.xy;
	float2 rg = tex2Dlod( _NoiseTex, float4((uv+0.5)/256.0, 0.0,0.)).yx;
	return lerp( rg.x, rg.y, f.z );
}

float fractal_noise(float3 p)
{
    float f = 0.0;
    // add animation
    p = p - float3(1.0, 1.0, 0.0) * _Time.y * 0.1;
    p = p * 3.0;
    f += 0.50000 * noise(p); p = 2.0 * p;
	f += 0.25000 * noise(p); p = 2.0 * p;
	f += 0.12500 * noise(p); p = 2.0 * p;
	f += 0.06250 * noise(p); p = 2.0 * p;
    f += 0.03125 * noise(p);
    
    return f;
}

float FBM( in float3 p )
{
	float3 q = p - float3(0.0,0.1,1.0)*_Time;
	float f;
    f  = 0.50000*noise( q ); q = q*2.02;
    f += 0.25000*noise( q ); q = q*2.03;
    f += 0.12500*noise( q );
	return clamp( 1.5 - p.y - 2.0 + 1.75*f, 0.0, 1.0 );
}

