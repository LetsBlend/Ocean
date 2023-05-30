// Upgrade NOTE: commented out 'float4x4 _CameraToWorld', a built-in variable
// Upgrade NOTE: replaced '_CameraToWorld' with 'unity_CameraToWorld'

// Upgrade NOTE: commented out 'float4x4 _CameraToWorld', a built-in variable
// Upgrade NOTE: replaced '_CameraToWorld' with 'unity_CameraToWorld'

// Upgrade NOTE: commented out 'float4x4 _CameraToWorld', a built-in variable
// Upgrade NOTE: replaced '_CameraToWorld' with 'unity_CameraToWorld'

// Upgrade NOTE: commented out 'float4x4 _CameraToWorld', a built-in variable
// Upgrade NOTE: replaced '_CameraToWorld' with 'unity_CameraToWorld'

// Upgrade NOTE: commented out 'float4x4 _CameraToWorld', a built-in variable
// Upgrade NOTE: replaced '_CameraToWorld' with 'unity_CameraToWorld'

// Upgrade NOTE: commented out 'float4x4 _CameraToWorld', a built-in variable
// Upgrade NOTE: replaced '_CameraToWorld' with 'unity_CameraToWorld'

// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

// Upgrade NOTE: commented out 'float4x4 _CameraToWorld', a built-in variable
// Upgrade NOTE: replaced '_CameraToWorld' with 'unity_CameraToWorld'

Shader "Hidden/LipShaderPP"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _WaveCount("WaveCount", Range(0, 1000)) = 1
        _MinLength("MinLength", float) = 1
        _MaxLength("MaxLength", float) = 1
        _MinAmplitude("MinAmplitude", float) = 1
        _MaxAmplitude("MaxAmplitude", float) = 1
        _MinSpeed("MinSpeed", Range(0, 10)) = 1
        _MaxSpeed("MaxSpeed", Range(0, 10)) = 1
        _Steepness("Steepness", Range(0, 1)) = 1
        _WindDirection("Wind Direction", Vector) = (0.8, 0.36, 0, 0)
        _WaveOffset("WaveOffset", Vector) = (1000, 0, 0, 0)
        _WaveSeed("Wave Seed", Vector) = (0, 0, 0, 0)
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
            #include "UnityCG.cginc"
            #pragma target 5.0

            #define PI 3.14159265359

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                uint vertexID : SV_VERTEXID;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float4 wPos : TEXCOORD1;
            };
            
            float4x4 _ClipToWorld;
            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);

                float4 vPos = mul(unity_CameraInvProjection, float4(o.vertex.xy, 1, 1)) * _ProjectionParams.y;
                o.wPos = mul(_ClipToWorld, float4(vPos.xyz, 1));

                o.uv = v.uv;
                return o;
            }

            sampler2D _MainTex;
            float4 permute(float4 x)
            {
                return fmod(34.0 * pow(x, 2) + x, 289.0);
            }

            float2 fade(float2 t)
            {
                return 6.0 * pow(t, 5.0) - 15.0 * pow(t, 4.0) + 10.0 * pow(t, 3.0);
            }

            float4 taylorInvSqrt(float4 r)
            {
                return 1.79284291400159 - 0.85373472095314 * r;
            }

            #define DIV_289 0.00346020761245674740484429065744f

            float mod289(float x)
            {
                return x - floor(x * DIV_289) * 289.0;
            }

            float PerlinNoise2D(float2 P)
            {
                float4 Pi = floor(P.xyxy) + float4(0.0, 0.0, 1.0, 1.0);
                float4 Pf = frac(P.xyxy) - float4(0.0, 0.0, 1.0, 1.0);

                float4 ix = Pi.xzxz;
                float4 iy = Pi.yyww;
                float4 fx = Pf.xzxz;
                float4 fy = Pf.yyww;

                float4 i = permute(permute(ix) + iy);

                float4 gx = frac(i / 41.0) * 2.0 - 1.0;
                float4 gy = abs(gx) - 0.5;
                float4 tx = floor(gx + 0.5);
                gx = gx - tx;

                float2 g00 = float2(gx.x, gy.x);
                float2 g10 = float2(gx.y, gy.y);
                float2 g01 = float2(gx.z, gy.z);
                float2 g11 = float2(gx.w, gy.w);

                float4 norm = taylorInvSqrt(float4(dot(g00, g00), dot(g01, g01), dot(g10, g10), dot(g11, g11)));
                g00 *= norm.x;
                g01 *= norm.y;
                g10 *= norm.z;
                g11 *= norm.w;

                float n00 = dot(g00, float2(fx.x, fy.x));
                float n10 = dot(g10, float2(fx.y, fy.y));
                float n01 = dot(g01, float2(fx.z, fy.z));
                float n11 = dot(g11, float2(fx.w, fy.w));

                float2 fade_xy = fade(Pf.xy);
                float2 n_x = lerp(float2(n00, n01), float2(n10, n11), fade_xy.x);
                float n_xy = lerp(n_x.x, n_x.y, fade_xy.y);
                return 2.3 * n_xy;
            }
            sampler2D _CameraDepthTexture;
            sampler2D _HeightMap;
            SamplerState my_linear_repeat_sampler;

            float2 _TransformScale;
            float3 _TransformPosition;
            int _Iterations;

            float3 NearPlanePos[4];

            //Waves
            int _WaveCount;
            float _MinLength, _MaxLength;
            float _MinAmplitude, _MaxAmplitude;
            float2 _WaveSeed;
            float2 _WaveOffset;
            float _MinSpeed, _MaxSpeed;
            float2 _WindDirection;
            float _Steepness;

            float3 GetWaterDisplacement(float3 position, v2f i){
                return tex2D(_HeightMap, (position.xz - _TransformPosition.xz) / _TransformScale);
            }
            float WhiteNoise(float2 uv)
            {
                return frac(sin(dot(uv, float2(12.9898, 78.233))) * 43758.5453);
            }
            float Remap(float iMin, float iMax, float oMin, float oMax, float v)
            {
                float t = (v - iMin) / (iMax - iMin);
                return lerp(oMin, oMax, t);
            }
            float Range(float min, float max, float i)
            {
                float rand = WhiteNoise(float2(i, i));
                if(rand == 0)
                return 1;
                return Remap(0, 1, min, max, rand);
            }
            float BiasedRange(float min, float max, float bias, float i)
            {
                float rand = WhiteNoise(float2(i, i));
                if(rand == 0)
                return 1;

                rand = pow(rand, bias);
                return Remap(0, 1, min, max, rand);
            }
            float3 GerstnerWave(float amplitude, float frequency, float steepness, float waveLength, float3 direction, float speed, float3 position){
                float time = _Time.y * 0;
                
                float x = direction.x * steepness * amplitude * cos(frequency * dot(direction, position) + time);
                float y =               amplitude * sin(frequency * dot(direction, position) + time);
                float z = direction.z * steepness * amplitude * cos(frequency * dot(direction, position) + time);

                return float3(x, y, z);
            }
            fixed4 frag (v2f i) : SV_Target
            {
                fixed4 col = tex2D(_MainTex, i.uv);

                //float3 inputPos = float3(i.wPos.x, _TransformPosition.y, i.wPos.z);
                //Getting correct sampleHeightPosition
                /*
                float3 pos = i.wPos;
                float3 newPos = i.wPos;
                
                for(int j = 0; j < _Iterations; j++){
                    newPos = pos - i.wPos;
                    pos = inputPos + GetWaterDisplacement(inputPos - newPos);
                }
                
                
                float3 disp = GetWaterDisplacement(inputPos, i);
                for(int j = 0; j < _Iterations; j++){
                    disp = GetWaterDisplacement(inputPos - disp, i);
                }
                disp = inputPos + GetWaterDisplacement(inputPos - disp, i);
                */

                //float h = PerlinNoise2D(i.wPos.xz * .3);
                //float h = _TransformPosition.y + tex2D(_HeightMap, (float2(disp.x, i.wPos.z) - _TransformPosition.xz) / _TransformScale).y;
                //fixed4 colH = tex2D(_HeightMap, i.uv);

                float3 inputPos = float3(i.wPos.x, 0, i.wPos.z);

                float3 p = 0;
                for(int z = 0; z < 3; z++){
                    float3 position = float3(i.wPos.x + _WaveOffset.x - p.x, 0, i.wPos.z + _WaveOffset.y - p.z);
                    p = 0;
                    for (int i = 0; i < _WaveCount; i++){
                        float waveLength = Remap(0, _WaveCount, _MinLength, _MaxLength, i);
                        float frequency = 2 * PI / waveLength;
                        float amplitude = Remap(0, _WaveCount, _MinAmplitude, _MaxAmplitude, i);
                        float speed = Range(_MinSpeed, _MaxSpeed, i + 400);
                        float3 dir = normalize(float3(BiasedRange(-1, 1, _WindDirection.x, i + _WaveSeed.x), 0.01f, BiasedRange(-1, 1, _WindDirection.y, i + _WaveSeed.y))); 
                        p += GerstnerWave(amplitude, frequency, _Steepness, waveLength, dir, speed, position);
                    }
                }

                float output = 0;
                if(i.wPos.y <= p.y)
                output = 1;
                //return colH;
                return fixed4(col.xyz + fixed3(0, 0, output.x), 1);
            }
            ENDCG
        }
    }
}