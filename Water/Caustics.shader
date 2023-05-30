Shader "Unlit/Caustics"
{
    Properties
    {
        _Caustics ("Caustics Texture", 2D) = "white" {}
        _NormalMap("NormalMap", 2D) = "normal" {}
        _Color("Color", Color) = (1, 1, 1, 1)
        _Direction("Direction", Vector) = (1, 1, 1, 1)
        _Speed("Speed", float) = 1
        _Distortion("Distortion", Range(0, 2)) = 1
        _Brightness("Brightness", float) = 1
        _CutOff("CutOff", float) = 0
        _AlphaOffset("TopAlphaOffset", float) = 0
        _AlphaOffsetCubeDown("Alpha Offset for the entire Cube from Below", Range(0, 1)) = 0
        _AlphaOffsetCubeUp("Alpha Offset for the entire Cube from Above", Range(0, 1)) = 0
    }

    SubShader
    {
        Tags{ "RenderType"="Transparent" "Queue"="Geometry+250m" "DisableBatching"="True"}
        Blend SrcAlpha OneMinusSrcAlpha 
        ZTest GEqual
        Zwrite Off
        Cull front
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float4 oPos : TEXCOORD0;
                float4 screenPos : TEXCOORD1;
                float3 ray : TEXCOORD2;
            };

            // Samplers for textures
            sampler2D _CameraDepthTexture;
            sampler2D _CameraDepthNormalsTexture;   
            sampler2D _Caustics;
            sampler2D _NormalMap;

            // Texture scaling and translation properties
            float4 _Caustics_ST;
            float4 _NormalMap_ST;

            // Properties for caustics animation
            float4 _Direction;
            float _Speed;
            float _Distortion;

            // Color and brightness properties
            float _Brightness;
            fixed4 _Color;

            // Alpha and cutoff properties
            float _CutOff;
            float _AlphaOffset;
            float _AlphaOffsetCubeDown;
            float _AlphaOffsetCubeUp;
            
            float4x4 _ViewToWorld;

            v2f vert (appdata v)
            {
                v2f o;
                // Calculate vertex position in screen space
                float4 wPos = mul(unity_ObjectToWorld, v.vertex);
                o.oPos = v.vertex;
                o.vertex = UnityWorldToClipPos(wPos);
                o.ray = wPos - _WorldSpaceCameraPos;
                o.screenPos = ComputeScreenPos(o.vertex);
                return o;
            }

            float3 getProjectedObjectPos(float2 screenPos, float3 worldRay)
            {
                float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, screenPos);
                depth = Linear01Depth(depth) * _ProjectionParams.z;

                // Get a ray that's 1 unit long on the axis from the camera (because depth is defined that way)
                worldRay = normalize(worldRay);

                // The 3rd row of the view matrix has the camera forward vector encoded, so a dot product with that will give the inverse distance in that direction
                worldRay /= dot(worldRay, -UNITY_MATRIX_V[2].xyz);

                // Reconstruct world and object space positions
                float3 worldPos = _WorldSpaceCameraPos + worldRay * depth;
                float3 objectPos =  mul(unity_WorldToObject, float4(worldPos, 1)).xyz;

                // Discard pixels where any component is beyond +-0.5
                clip(0.5 - abs(objectPos));

                // Convert -0.5|0.5 space to 0|1 for proper texture UVs
                objectPos += 0.5;
                return objectPos;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // Get screen UVs and DepthNormals
                float2 screenUv = i.screenPos.xy / i.screenPos.w;
                float3 obj = getProjectedObjectPos(screenUv, i.ray);
                float2 uv = obj.xz;

                // Get the normal from the NormalMap texture
                half3 normal = UnpackNormal(tex2D(_NormalMap, uv * _NormalMap_ST.xy + _NormalMap_ST.zw));

                // Get the world-space normal from the DepthNormals texture
                float4 depthNormal = tex2D(_CameraDepthNormalsTexture, screenUv);
                float3 wNormal;
                float depth;
                DecodeDepthNormal(depthNormal, depth, wNormal);
                wNormal = wNormal = mul((float3x3)_ViewToWorld, wNormal);

                // Read the texture color at the UV coordinate with offset for caustics animation
                float2 offset = _Caustics_ST.zw + _Direction.xy * _Time.y * _Speed + normal.xy * _Distortion;
                fixed4 col = tex2D(_Caustics, uv * _Caustics_ST.xy + offset);

                // Read the texture color at the UV coordinate with offset for caustics animation
                offset = _Caustics_ST.zw + _Direction.zw * _Time.y * _Speed + normal.xy * _Distortion;
                col += tex2D(_Caustics, uv * _Caustics_ST.xy + offset);
                col = saturate(col);

                col *= _Color;

                // Smooth falloff at edges based on normal and alpha properties
                float luminance = dot(col.xyz, float3(0.3, 0.59, 0.11));
                float alpha = saturate(luminance * _CutOff) * saturate(dot(wNormal, float3(0, 1, 0)) + _AlphaOffset);
                alpha = saturate(lerp(0, alpha, obj.y - _AlphaOffsetCubeDown));
                alpha = saturate(lerp(alpha, 0, obj.y + _AlphaOffsetCubeUp));

                return fixed4(col.xyz * _Brightness, alpha);
            }
            ENDCG
        }
    }
}
