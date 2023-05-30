Shader "Unlit/WaterLipp"
{
    Properties
    {
        _Skybox ("SkyBox", Cube) = "" {}
        _Rotation("Rotation", float) = 0
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
        _Precision("Precision", float) = 1

        _LensDistortionPower("Lens Distortion Power", float) = 1
        _LensDistortionOffset("Lens Distortion Offset", float) = 0

        _NormalMap("Distortion Normal", 2D) = "normal" {}
        _DistortionStrength("Distortion Strength", float) = 1
        _DistortionSpeed("Distortion Speed", float) = 1

        _VigneteStrength("Vignete Strength", float) = 1
        _VigneteOffset("Vignete Offset", float) = 0

        _ChromAborationOffsets("Chromatic Aboration Offsets", Vector) = (0, 0, 0, 0 )

        _Temperature("Temperature", float) = 0
        _Tint("Tint", float) = 0

        _ColorFilter("Color Filter", Color) = (1, 1, 1, 1)

        _OutsideFogDensity("Above Water Fog Density", Range(0, 1)) = 0.01
        _OutsideFogOffset("Above Fog Offset", float) = 0
        _OutsideFogColor("Above Fog Color", Color) = (.6, .6, .6, 1)

        _FogDensity("UnderWater Fog", Range(0, 1)) = 0.01
        _FogOffset("Fog Offset", float) = 0
        _FogColor("Fog Color", Color) = (.6, .6, .6, 1)

        _Gamma("Gamma Correction", float) = 1
    }
    SubShader
    {
        Tags { "Queue"="Transparent" "RenderType"="Transparent" }
        Zwrite off
        LOD 100
        
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work

            #include "UnityCG.cginc"

            #define PI 3.14159265359

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 wPos : TEXCOORD1;
                float height : TEXCOORD2;
                float3 viewVector : TEXCOORD3;
            };

            sampler2D _BackGround;
            sampler2D _CameraDepthTexture;
            sampler2D _CameraDepthBuffer;

            float _NearClippHeight;

            //Waves
            int _WaveCount;
            float _MinLength, _MaxLength;
            float _MinAmplitude, _MaxAmplitude;
            float2 _WaveSeed;
            float2 _WaveOffset;
            float _MinSpeed, _MaxSpeed;
            float2 _WindDirection;
            float _Steepness;

            float _Precision;

            //Visuals
            samplerCUBE _Skybox;
            float _Rotation;

            sampler2D _NormalMap;
            float _DistortionStrength;
            float _DistortionSpeed;

            float _LensDistortionPower;
            float _LensDistortionOffset;

            float _VigneteStrength;
            float _VigneteOffset;

            float3 _ChromAborationOffsets;

            float _Temperature;
            float _Tint;

            fixed4 _ColorFilter;

            float _OutsideFogDensity;
            float _OutsideFogOffset;
            fixed4 _OutsideFogColor;

            float _FogDensity;
            float _FogOffset;
            fixed4 _FogColor;

            float _Gamma;

            // Generates white noise based on a given input
            float WhiteNoise(float2 uv)
            {
                return frac(sin(dot(uv, float2(12.9898, 78.233))) * 43758.5453);
            }

            // Remaps a value from one range to another
            float Remap(float iMin, float iMax, float oMin, float oMax, float v)
            {
                float t = (v - iMin) / (iMax - iMin);
                return lerp(oMin, oMax, t);
            }

            // Generates a random value within a given range based on an input value
            float Range(float min, float max, float i)
            {
                float rand = WhiteNoise(float2(i, i));
                if(rand == 0)
                return 1;
                return Remap(0, 1, min, max, rand);
            }

            // Generates a biased random value within a given range based on an input value and bias
            float BiasedRange(float min, float max, float bias, float i)
            {
                float rand = WhiteNoise(float2(i, i));
                if(rand == 0)
                return 1;

                rand = pow(rand, bias);
                return Remap(0, 1, min, max, rand);
            }

            // Computes the position of a Gerstner wave at a given point in space
            float3 GerstnerWave(float amplitude, float frequency, float steepness, float waveLength, float3 direction, float speed, float3 position)
            {
                float time = _Time.y * speed;

                float x = direction.x * steepness * amplitude * cos(frequency * dot(direction, position) + time);
                float y =               amplitude * sin(frequency * dot(direction, position) + time);
                float z = direction.z * steepness * amplitude * cos(frequency * dot(direction, position) + time);

                return float3(x, y, z);
            }

            // Vertex shader function
            v2f vert (appdata v)
            {
                v2f o;
                o.uv = v.uv;
                o.vertex = UnityObjectToClipPos(v.vertex);

                o.wPos = mul(unity_ObjectToWorld, v.vertex);
                float3 p = 0;

                for(int z = 0; z < _Precision; z++)
                {
                    float3 position = float3(o.wPos.x + _WaveOffset.x - p.x, 0, o.wPos.z + _WaveOffset.y - p.z);
                    p = 0;

                    for (int i = 0; i < _WaveCount; i++)
                    {
                        float waveLength = Remap(0, _WaveCount, _MinLength, _MaxLength, i);
                        float frequency = 2 * PI / waveLength;
                        float amplitude = Remap(0, _WaveCount, _MinAmplitude, _MaxAmplitude, i);
                        float speed = Range(_MinSpeed, _MaxSpeed, i + 400);
                        float3 dir = normalize(float3(BiasedRange(-1, 1, _WindDirection.x, i + _WaveSeed.x), 0.01f, BiasedRange(-1, 1, _WindDirection.y, i + _WaveSeed.y))); 
                        p += GerstnerWave(amplitude, frequency, _Steepness, waveLength, dir, speed, position);
                    }
                }
                o.height = p.y;
                float3 viewVector = mul(unity_CameraInvProjection, float4(v.uv * 2 - 1, 0, -1));
                o.viewVector = mul(unity_CameraToWorld, float4(viewVector,0));
                return o;
            }
            //https://docs.unity3d.com/Packages/com.unity.shadergraph@6.9/manual/White-Balance-Node.html
            float3 WhiteBalance(float3 col, float temp, float tint) {
                float t1 = temp * 10.0f / 6.0f;
                float t2 = tint * 10.0f / 6.0f;

                float x = 0.31271 - t1 * (t1 < 0 ? 0.1 : 0.05);
                float standardIlluminantY = 2.87 * x - 3 * x * x - 0.27509507;
                float y = standardIlluminantY + t2 * 0.05;

                float3 w1 = float3(0.949237, 1.03542, 1.08728);

                float Y = 1;
                float X = Y * x / y;
                float Z = Y * (1 - x - y) / y;
                float L = 0.7328 * X + 0.4296 * Y - 0.1624 * Z;
                float M = -0.7036 * X + 1.6975 * Y + 0.0061 * Z;
                float S = 0.0030 * X + 0.0136 * Y + 0.9834 * Z;
                float3 w2 = float3(L, M, S);

                float3 balance = float3(w1.x / w2.x, w1.y / w2.y, w1.z / w2.z);

                float3x3 LIN_2_LMS_MAT = {
                    3.90405e-1, 5.49941e-1, 8.92632e-3,
                    7.08416e-2, 9.63172e-1, 1.35775e-3,
                    2.31082e-2, 1.28021e-1, 9.36245e-1
                };

                float3x3 LMS_2_LIN_MAT = {
                    2.85847e+0, -1.62879e+0, -2.48910e-2,
                    -2.10182e-1,  1.15820e+0,  3.24281e-4,
                    -4.18120e-2, -1.18169e-1,  1.06867e+0
                };

                float3 lms = mul(LIN_2_LMS_MAT, col);
                lms *= balance;
                return mul(LMS_2_LIN_MAT, lms);
            }
            float3 RotateY(float3 dir){
                float2x2 rot = {
                    cos(_Rotation), -sin(_Rotation),
                    sin(_Rotation), cos(_Rotation)
                };
                float2 d = mul(rot, dir.xz).xy;
                return float3(d.x, dir.y, d.y);
            }
            fixed4 frag (v2f i) : SV_Target
            {
                //-----Return to Above Water/Gamma Correct-----
                fixed4 col = tex2D(_BackGround, i.uv);
                fixed4 skybox = texCUBE(_Skybox, RotateY(i.viewVector));
                float depth = Linear01Depth(SAMPLE_DEPTH_TEXTURE(_CameraDepthBuffer, i.uv));
                
                if(i.wPos.y > i.height)
                return depth >= .9 ? skybox.xyzx : pow(col, _Gamma);

                //---------Distortion---------
                float2 uvNormal = i.uv * .1;
                half3 normalA = UnpackNormal(tex2D(_NormalMap, uvNormal + float2(.1, .3) * _Time.y * _DistortionSpeed));
                half3 normalB = UnpackNormal(tex2D(_NormalMap, uvNormal + float2(.02, .075) * _Time.y * _DistortionSpeed));
                half3 normal = normalA * normalB;

                float2 uvOffset = normal * _DistortionStrength;

                //-------Lens Distortion------
                float vigneteMask = saturate(pow(1-saturate(length((i.uv - .5) * 1.5)), _LensDistortionPower) + _LensDistortionOffset);
                float2 uv = lerp((i.uv - .5) * .7 + .5, i.uv, vigneteMask);
                uv += uvOffset;

                //----Chromatic Aboration-----
                float mask = 1-saturate(pow(1-saturate(length((i.uv - .5) * 1.5)), 1) + .4);
                float r = tex2D(_BackGround, uv + _ChromAborationOffsets.x * mask).r;
                float g = tex2D(_BackGround, uv + _ChromAborationOffsets.y * mask).g;
                float b = tex2D(_BackGround, uv + _ChromAborationOffsets.z * mask).b;
                col = fixed4(r, g, b, 1);

                //-------------Fog------------
                depth = Linear01Depth(SAMPLE_DEPTH_TEXTURE(_CameraDepthBuffer, uv));
                float viewDistance = depth * _ProjectionParams.z;
                
                float fogFactor = (_FogDensity / sqrt(log(2))) * max(0.0f, viewDistance - _FogOffset);
                fogFactor = exp2(-fogFactor * fogFactor);

                float4 fogCol = lerp(_FogColor, col, saturate(fogFactor));
                //-----------Vignete----------
                vigneteMask = saturate(pow(1-saturate(length((i.uv - .5) * 1.5)), _VigneteStrength) + _VigneteOffset);
                fogCol *= vigneteMask;
                
                //-------White Balancing------
                fogCol.xyz = WhiteBalance(fogCol, _Temperature, _Tint);

                //------Color Filtering-------
                fogCol *= _ColorFilter;

                //------Gamma Correction------
                fogCol = pow(fogCol, _Gamma);

                return fogCol;
            }
            ENDCG
        }
    }
}
