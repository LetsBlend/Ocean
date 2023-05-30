Shader "Unlit/Ocean"
{
    Properties
    {
        // Texture property for the main texture of the ocean
        _MainTex ("Texture", 2D) = "white" {}
        
        // Properties related to wave generation
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
        
        // Properties related to color and shading
        _Color("Color", Color) = (1, 1, 1, 1)
        _Normal("Additional Normals", 2D) = "bump" {}
        _WaveNormalSpeed("Wave Normal Speed", float) = 1
        _DiffuseWrap("DiffuseWrap", Range(0, 2)) = 0
        _Glossiness("Glossiness", Range(0, 1)) = 0.5
        _Roughness("Roughness", Range(0, 1)) = 1
        _SkyBoxInfluence("SkyBoxInfluence", Range(0, 1)) = 1
        _DepthThroughWater("DepthThroughWater", Range(0, 2)) = 1
        _RefractionStrength("RefractionStrength", Range(0, 2)) = 1
        _ReflectionStrength("ReflectionStrength", Range(0, 1)) = 1
        _ReflectionDistortionStrength("ReflectionDistortionStrength", Range(0, 2)) = 1
        _FresnelReflectionOffset("FresnelReflectionOffset", Range(-1, 1)) = 0
        _FresnelSpecularOffset("FresnelSpecularOffset", Range(-1, 1)) = 0
        _SSSColor("SSSColor", Color) = (1, 1, 1, 1)
        _SSSPower("SSSPower", float) = 1
        _SSStrength("SSSStrength", float) = 1
        _SSSOffset("SSSOffset", float) = .3
        _SSSViewOffset("SSSViewOffset", float) = .3
        _FoamAmount("FoamAmount", float) = 0
        _FoamBrightness("Foam Brightness", float) = 0
        _FoamStrength("FoamStrength", float) = 0
        
        // Properties related to tessellation and LOD
        _TessellationEdgeLength ("Tessellation Edge Length", float) = 50
        _MaxTessellation("Max Tessellation", Range(1, 100)) = 1
        _TessellationOffset("Tessellation Bias", float) = 50
        _CloseTessellationOffset("CloseTessellationOffset", float) = 1
        _TessellationCullingBias("Tessellation Culling Bias", float) = 0
        _LODCutOff("LOD Cut Off", float) = 100
        _WindingCullingBias("Winding Culling Bias", float) = 0
    }
    SubShader
    {
        Tags { "Queue"="AlphaTest" "RenderType"="Opaque" }
        Zwrite on
        Cull off
        LOD 100

        GrabPass {"_WaterBackGround"}

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma hull HullProgram
            #pragma domain DomainProgram
            #pragma 3.0

            // Include necessary shader files
            #include "UnityCG.cginc"
            #include "UnityLightingCommon.cginc"

            // Define constants
            #define PI 3.14159265359
            #define MY_DOMAIN_PROGRAM_INTERPOLATE(fieldName) data.fieldName = \
            patch[0].fieldName * barycentricCoordinates.x + \
            patch[1].fieldName * barycentricCoordinates.y + \
            patch[2].fieldName * barycentricCoordinates.z;

            // Define input vertex structure
            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
            };

            // Define control point for tessellation
            struct TessellationControlPoint {
                float4 vertex : INTERNALTESSPOS;
                float2 uv : TEXCOORD0;
            };

            // Define interpolated data structure
            struct Interpolators
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 normal : TEXCOORD1;
                float3 tangent : TEXCOORD2;
                float3 binormal : TEXCOORD3;
                float3 forwardVector : TEXCOORD4;
                float4 wPos : TEXCOORD5;
                float3 ambient : TEXCOORD6;
                float4 screenPos : TEXCOORD7;
                float foam : TEXCOORD8;
            };

            // Define tessellation factors structure
            struct TessellationFactors {
                float edge[3] : SV_TessFactor;
                float inside : SV_InsideTessFactor;
            };

            // Define texture samplers
            sampler2D _MainTex;
            float4 _MainTex_ST;

            sampler2D _CameraDepthTexture;
            sampler2D _WaterBackGround;
            SamplerState my_point_clamp_sampler;
            float4 _CameraDepthTexture_TexelSize;

            sampler2D _DisplacementMap;
            sampler2D _NormalMap;
            sampler2D _Normal;
            float4 _Normal_ST;
            sampler2D _ReflectionTex;
            float2 _WaveDirection;

            // Define material properties
            fixed4 _Color;
            float _DiffuseWrap;
            float _Glossiness;
            float _Roughness;
            float _SkyBoxInfluence;

            float2 _TransformScale;
            float3 _TransformPosition;

            float _DepthThroughWater;
            float _RefractionStrength;

            float4x4 _ViewToWorld;

            int _ReflectionType;
            float _ReflectionStrength;
            float _ReflectionDistortionStrength;
            float _FresnelReflectionOffset;
            float _FresnelSpecularOffset;

            float _SSSPower;
            float _SSStrength;
            fixed4 _SSSColor;
            float _SSSOffset;
            float _SSSViewOffset;

            float _FoamAmount;
            float _FoamBrightness;
            float _FoamStrength;

            float _WaveNormalSpeed;

            float _TessellationEdgeLength;
            float _MaxTessellation;
            float _TessellationOffset;
            float _CloseTessellationOffset;
            float _TessellationCullingBias;
            float _LODCutOff;
            float _WindingCullingBias;

            //Waves
            int _WaveCount;
            float _MinLength, _MaxLength;
            float _MinAmplitude, _MaxAmplitude;
            float2 _WaveSeed;
            float2 _WaveOffset;
            float _MinSpeed, _MaxSpeed;
            float2 _WindDirection;
            float _Steepness;

            // Function to generate white noise based on a given input vector
            float WhiteNoise(float2 uv)
            {
                return frac(sin(dot(uv, float2(12.9898, 78.233))) * 43758.5453);
            }

            // Function to remap a value from one range to another
            float Remap(float iMin, float iMax, float oMin, float oMax, float v)
            {
                float t = (v - iMin) / (iMax - iMin);
                return lerp(oMin, oMax, t);
            }

            // Function to generate a random value within a given range based on an input index
            float Range(float min, float max, float i)
            {
                float rand = WhiteNoise(float2(i, i));
                if (rand == 0)
                return 1;
                return Remap(0, 1, min, max, rand);
            }

            // Function to generate a biased random value within a given range based on an input index
            float BiasedRange(float min, float max, float bias, float i)
            {
                float rand = WhiteNoise(float2(i, i));
                if (rand == 0)
                return 1;

                rand = pow(rand, bias);
                return Remap(0, 1, min, max, rand);
            }

            // Function to calculate a Gerstner wave displacement based on given parameters
            float3 GerstnerWave(float amplitude, float frequency, float steepness, float waveLength, float3 direction, float speed, float3 position, inout float3 tangent, inout float3 binormal)
            {
                float time = _Time.y * speed;

                float x = direction.x * steepness * amplitude * cos(frequency * dot(direction, position) + time);
                float y = amplitude * sin(frequency * dot(direction, position) + time);
                float z = direction.z * steepness * amplitude * cos(frequency * dot(direction, position) + time);

                tangent += float3(
                direction.x * direction.x * (frequency * amplitude * sin(frequency * dot(direction, position) + time)),
                direction.x * (frequency * amplitude * cos(frequency * dot(direction, position) + time)),
                direction.x * direction.z * (frequency * amplitude * sin(frequency * dot(direction, position) + time))
                );

                binormal += float3(
                direction.x * direction.z * (frequency * amplitude * sin(frequency * dot(direction, position) + time)),
                direction.z * (frequency * amplitude * cos(frequency * dot(direction, position) + time)),
                direction.z * direction.z * (frequency * amplitude * sin(frequency * dot(direction, position) + time))
                );

                return float3(x, y, z);
            }

            // Vertex function for tessellation control shader
            TessellationControlPoint vert(appdata v)
            {
                TessellationControlPoint o;
                o.vertex = v.vertex;
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

            // Function to calculate the tessellation edge factor between two points
            float TessellationEdgeFactor(float3 p0, float3 p1)
            {
                float edgeLength = distance(p0, p1);

                float3 edgeCenter = (p0 + p1) * 0.5;
                float viewDistance = distance(edgeCenter, _WorldSpaceCameraPos);

                float factor = edgeLength * _ScreenParams.y / (_TessellationEdgeLength * viewDistance * viewDistance);
                return min(max(1, factor + _TessellationOffset), _MaxTessellation);
            }
            bool ShouldLODCutOff(float3 p0, float3 p1, float3 p2){
                // Calculate the distance between the camera and each point of the triangle
                float p0dist = distance(_WorldSpaceCameraPos, p0);
                float p1dist = distance(_WorldSpaceCameraPos, p0);
                float p2dist = distance(_WorldSpaceCameraPos, p0);
                
                // Check if all points are farther than the LOD cutoff distance
                // If true, return true; otherwise, return false
                return p0dist >= _LODCutOff && p1dist >= _LODCutOff && p2dist >= _LODCutOff ? true : false;
            }

            bool IsOutOfBounds(float3 p, float3 lower, float3 higher){
                // Check if the given point is outside the specified lower and higher bounds in all axes
                return p.x < lower.x || p.x > higher.x || p.y < lower.y || p.y > higher.y || p.z < lower.z || p.z > higher.z;
            }

            bool IsPointOutOfFrustum(float4 position, float tolerance) {
                // Extract the position from the given homogeneous coordinates
                float3 culling = position.xyz;
                float w = position.w;
                
                // Calculate the lower and higher bounds for each axis, considering a tolerance value
                // UNITY_RAW_FAR_CLIP_VALUE/UNITY_UV_STARTS_AT_TOP is either 0 or 1, depending on graphics API
                // Most use 0, however OpenGL uses 1
                float3 lowerBounds = float3(-w - tolerance, -w - tolerance, -w * UNITY_UV_STARTS_AT_TOP - tolerance);
                float3 higherBounds = float3(w + tolerance, w + tolerance, w + tolerance);
                
                // Check if the culling point is outside the bounds
                return IsOutOfBounds(culling, lowerBounds, higherBounds);
            }

            bool ShouldClipPatch(float4 p0, float4 p1, float4 p2){
                // Check if any of the triangle points are outside the frustum or if the LOD cutoff condition is met
                bool outside = IsPointOutOfFrustum(UnityWorldToClipPos(p0), _TessellationCullingBias) && IsPointOutOfFrustum(UnityWorldToClipPos(p1), _TessellationCullingBias) && IsPointOutOfFrustum(UnityWorldToClipPos(p2), _TessellationCullingBias);
                return outside || ShouldLODCutOff(p0, p1, p2);
            }
            TessellationFactors MyPatchConstantFunction (InputPatch<TessellationControlPoint, 3> patch) {
                float4 p0 = mul(unity_ObjectToWorld, patch[0].vertex);
                float4 p1 = mul(unity_ObjectToWorld, patch[1].vertex);
                float4 p2 = mul(unity_ObjectToWorld, patch[2].vertex);
                TessellationFactors f;
                if(ShouldClipPatch(p0, p1, p2)){
                    f.edge[0] = f.edge[1] = f.edge[2] = f.inside = 0; 
                    return f;
                }
                
                f.edge[0] = TessellationEdgeFactor(p1, p2);
                f.edge[1] = TessellationEdgeFactor(p2, p0);
                f.edge[2] = TessellationEdgeFactor(p0, p1);
                f.inside = (TessellationEdgeFactor(p1, p2) + TessellationEdgeFactor(p2, p0) + TessellationEdgeFactor(p0, p1)) * (1 / 3.0);
                return f;
            }
            [UNITY_domain("tri")]
            [UNITY_outputcontrolpoints(3)]
            [UNITY_outputtopology("triangle_cw")]
            [UNITY_partitioning("fractional_odd")]
            [UNITY_patchconstantfunc("MyPatchConstantFunction")]
            TessellationControlPoint HullProgram (InputPatch<TessellationControlPoint, 3> patch, uint id : SV_OutputControlPointID)
            {
                return patch[id];
            }
            Interpolators vertex(Interpolators v){
                v.wPos = mul(unity_ObjectToWorld, v.vertex);
                float3 p = 0;

                float3 tangent;
                float3 binormal;

                float3 ddx = 0;
                float3 ddy = 0;
                float3 ddz = 0;
                for (int i = 0; i < _WaveCount; i++){
                    float waveLength = Remap(0, _WaveCount, _MinLength, _MaxLength, i);
                    float frequency = 2 * PI / waveLength;
                    float amplitude = Remap(0, _WaveCount, _MinAmplitude, _MaxAmplitude, i);
                    float speed = Range(_MinSpeed, _MaxSpeed, i + 400);
                    float3 dir = normalize(float3(BiasedRange(-1, 1, _WindDirection.x, i + _WaveSeed.x), 0.01f, BiasedRange(-1, 1, _WindDirection.y, i + _WaveSeed.y))); 
                    float3 position = float3(v.wPos.x + _WaveOffset.x, 0, v.wPos.z + _WaveOffset.y);

                    p += GerstnerWave(amplitude, frequency, _Steepness, waveLength, dir, speed, position, tangent, binormal);

                    float negSin = -sin(frequency * dot(dir, position) + speed * _Time);
                    ddx.x += dir.x * dir.x * _Steepness * amplitude * negSin;
                    ddx.y += dir.x * dir.y * _Steepness * amplitude * negSin;
                    ddx.z += dir.x * dir.z * _Steepness * amplitude * negSin;

                    float posCos = cos(frequency * dot(dir, position) + speed * _Time);
                    ddy.x += amplitude * dir.x * posCos;
                    ddy.y += amplitude * dir.y * posCos;
                    ddy.z += amplitude * dir.z * posCos;

                    ddz.x += dir.z * dir.x * _Steepness * amplitude * negSin;
                    ddz.y += dir.z * dir.y * _Steepness * amplitude * negSin;
                    ddz.z += dir.z * dir.z * _Steepness * amplitude * negSin;
                }
                v.tangent = normalize(float3(1-tangent.x, tangent.y, -tangent.z));
                v.binormal = normalize(float3(-binormal.x, binormal.y, 1-binormal.z));
                v.normal = normalize(cross(v.binormal, v.tangent));

                //Foam
                float3x3 jacobian = {
                    ddx.x, ddx.y, ddx.z,
                    ddy.x, ddy.y, ddy.z,
                    ddz.x, ddz.y, ddz.z
                };
                v.foam = determinant(jacobian);

                v.vertex = UnityWorldToClipPos(float4(v.wPos.x + p.x, p.y, v.wPos.z + p.z, v.wPos.w));
                v.screenPos = ComputeScreenPos(v.vertex);
                v.forwardVector = mul((float3x3)unity_CameraToWorld, float3(0, 0, 1));
                v.ambient = ShadeSH9(half4(v.normal, 1));
                return v;
            }

            [UNITY_domain("tri")]
            Interpolators DomainProgram (TessellationFactors factors, OutputPatch<TessellationControlPoint, 3> patch, float3 barycentricCoordinates : SV_DomainLocation)
            {
                Interpolators data;
                MY_DOMAIN_PROGRAM_INTERPOLATE(vertex)
                MY_DOMAIN_PROGRAM_INTERPOLATE(uv)
                return vertex(data);
            }
            fixed4 frag (Interpolators i) : SV_Target
            {
                //----------Water Normals-----------
                float3 normal = i.normal;

                float3x3 TangToWorld = {
                    i.tangent.x, i.binormal.x, normal.x,
                    i.tangent.y, i.binormal.y, normal.y,
                    i.tangent.z, i.binormal.z, normal.z,
                };

                //-------Diffuse Light-------
                float wrapdiffuse = saturate((dot(_WorldSpaceLightPos0, normal) + _DiffuseWrap) / (1 + _DiffuseWrap)) * 4;
                float3 diffuseLight = wrapdiffuse * _LightColor0.xyz;
                diffuseLight += i.ambient;
                float4 surfaceColor = saturate(float4(diffuseLight * _Color.xyz, _Color.w));

                //-------Specular Light-------
                float3 viewVector = normalize(_WorldSpaceCameraPos - i.wPos);

                float3 halfVector = normalize(_WorldSpaceLightPos0 + viewVector);
                float3 specularLight = saturate(dot(halfVector, normalize(normal))); //Blinn Phong

                float specularExponent = exp2(_Glossiness * 8) + 1;
                specularLight = pow(specularLight, specularExponent) * _Glossiness;
                specularLight *= _LightColor0.xyz;
                //return fixed4(specularLight.xyz, 1);

                float3 worldReflection = reflect(-viewVector, normal);
                half4 skyData = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, worldReflection, 1-_Roughness);
                half3 skyColor = DecodeHDR(skyData, unity_SpecCube0_HDR);
                specularLight += skyColor * _SkyBoxInfluence * saturate(_Glossiness - .5);
                
                //-------Sub Surface Scattering-------
                float mask = 1-saturate(determinant(TangToWorld + _SSSOffset));//saturate(dot(float3(0, 1, 0), normal) + _SSSOffset) * 100;
                float SSSContribution = saturate((dot(-_WorldSpaceLightPos0, viewVector) + _SSSViewOffset) / (1 + _SSSViewOffset) * 4);
                float4 SSS = _SSSColor * mask * SSSContribution;
                surfaceColor += max(0, pow(SSS, _SSSPower) * _SSStrength);

                //-------Planar Reflection-------
                float2 uvOffset = normal * _ReflectionDistortionStrength;
                uvOffset.y -= _ReflectionDistortionStrength;
                uvOffset.y *= _CameraDepthTexture_TexelSize.z * abs(_CameraDepthTexture_TexelSize.y);
                float2 uv = (i.screenPos.xy + uvOffset) / i.screenPos.w;

                float3 ref = tex2D(_ReflectionTex, float2(1-uv.x, uv.y));
                float3 reflection = ref * saturate(_Glossiness - .5) * _ReflectionStrength; 

                
                //-------Refraction-------
                uvOffset = normal * _RefractionStrength;
                uvOffset.y -= _RefractionStrength;
                uvOffset.y *= _CameraDepthTexture_TexelSize.z * abs(_CameraDepthTexture_TexelSize.y);
                uv = (i.screenPos.xy + uvOffset) / i.screenPos.w;

                float dstToTerrain = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv));
                float dstToWater = i.screenPos.w;
                float waterViewDepth = dstToTerrain - dstToWater;

                if(waterViewDepth < 0){
                    uv = (i.screenPos.xy) / i.screenPos.w;
                    #if UNITY_UV_STARTS_AT_TOP
                        if (_CameraDepthTexture_TexelSize.y < 0) {
                            uv.y = 1 - uv.y;
                        }
                    #endif  
                }
                float3 backGroundColor = tex2D(_WaterBackGround, uv);

                //-------Depth-------
                dstToTerrain = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv));
                dstToWater = i.screenPos.w;
                waterViewDepth = dstToTerrain - dstToWater;
                
                float depthThroughWater = saturate(1-exp(-waterViewDepth * _DepthThroughWater));

                //------------Foam-----------
                float foam1 = saturate(1-saturate(dot(normal, normalize(float3(_WaveDirection.x, 10, _WaveDirection.y))) + _FoamAmount) * _FoamStrength);

                //-------Fernel Effect-------
                float fresnel = 1-abs(dot(normalize(i.forwardVector), float3(0, 1, 0)));

                float3 finalColor = lerp(backGroundColor, surfaceColor, depthThroughWater);
                finalColor = lerp(finalColor, surfaceColor + reflection, saturate(fresnel + _FresnelReflectionOffset));
                finalColor = lerp(finalColor, finalColor + specularLight, saturate(fresnel + _FresnelSpecularOffset));
                finalColor = finalColor + saturate(foam1 * i.foam) * _FoamBrightness;

                //------------Fog--------------
                float depth = distance(_WorldSpaceCameraPos, i.wPos);
                float fog = exp2(-((depth * unity_FogParams.x) * (depth * unity_FogParams.x)));
                return fixed4(lerp(unity_FogColor, finalColor, fog), depthThroughWater);
            }
            ENDCG
        }
    }
}
