Shader "FullScreen/FullScreenScanner"
{
	Properties
	{
		_PerspectiveType("Perspective (0, 1, 2)", float) = 0

		//_MainTex("Camera Texture", 2D) = "white" {}
		//_ScanTex("Scan Texture", 2D) = "white" {}
		_ScanDistance("Scan Distance", float) = 0
		_MaxScanDistance("Max Scan Distance", float) = 250
		_ScanDistanceOffset("Offset Between Scan Waves", float) = 1
		_ScanWidth("First Scan Width", float) = 10
		_SubsequentScanWidth("Second Scan Width", float) = 2
		_LeadSharp("Leading Edge Sharpness", float) = 10
		_LeadColor("Leading Edge Color Above", Color) = (1, 1, 1, 0)
		_MidColor("Mid Color Above", Color) = (1, 1, 1, 0)
		_TrailColor("Trail Color Above", Color) = (1, 1, 1, 0)

		_BelowOffset("Color Change Y-Offset", float) = 2
		_CutoffTreshold("Color Change Grandient Treshold", float) = 1
		_LeadColorBelow("Leading Edge Color Below", Color) = (1, 1, 1, 0)
		_MidColorBelow("Mid Color Below", Color) = (1, 1, 1, 0)
		_TrailColorBelow("Trail Color Below ", Color) = (1, 1, 1, 0)

	}
    HLSLINCLUDE

    #pragma vertex Vert

    #pragma target 4.5
    #pragma only_renderers d3d11 playstation xboxone vulkan metal switch

    #include "Packages/com.unity.render-pipelines.high-definition/Runtime/RenderPipeline/RenderPass/CustomPass/CustomPassCommon.hlsl"
	#include "Packages/com.unity.render-pipelines.high-definition/Runtime/ShaderLibrary/ShaderVariables.hlsl"

    // The PositionInputs struct allow you to retrieve a lot of useful information for your fullScreenShader:
    // struct PositionInputs
    // {
    //     float3 positionWS;  // World space position (could be camera-relative)
    //     float2 positionNDC; // Normalized screen coordinates within the viewport    : [0, 1) (with the half-pixel offset)
    //     uint2  positionSS;  // Screen space pixel coordinates                       : [0, NumPixels)
    //     uint2  tileCoord;   // Screen tile coordinates                              : [0, NumTiles)
    //     float  deviceDepth; // Depth from the depth buffer                          : [0, 1] (typically reversed)
    //     float  linearDepth; // View space Z coordinate                              : [Near, Far]
    // };

    // To sample custom buffers, you have access to these functions:
    // But be careful, on most platforms you can't sample to the bound color buffer. It means that you
    // can't use the SampleCustomColor when the pass color buffer is set to custom (and same for camera the buffer).
    // float4 SampleCustomColor(float2 uv);
    // float4 LoadCustomColor(uint2 pixelCoords);
    // float LoadCustomDepth(uint2 pixelCoords);
    // float SampleCustomDepth(float2 uv);

    // There are also a lot of utility function you can use inside Common.hlsl and Color.hlsl,
    // you can check them out in the source code of the core SRP package.

	struct VertIn
	{
		float4 vertex : POSITION;
		float2 uv : TEXCOORD0;
		float4 ray : TEXCOORD1;
	};

	struct VertOut
	{
		float4 vertex : SV_POSITION;
		float2 uv : TEXCOORD0;
		//float2 uv_depth : TEXCOORD1;
		//float4 interpolatedRay : TEXCOORD2;
	};

	TEXTURE2D_X(_MainTex);
	sampler2D _ScanTex;
	//TEXTURE2D(_CameraDepthTexture);

	float _PerspectiveType;

	int _NumberOfScans;
	float4 _WorldSpaceScannerPos;
	float4 _SubsequentWorldSpaceScannerPos;
	float _ScanDistance;
	float _MaxScanDistance;
	float _ScanDistanceOffset;
	float _ScanWidth;
	float _SubsequentScanWidth;
	float _LeadSharp;
	float4 _LeadColor;
	float4 _MidColor;
	float4 _TrailColor;
	
	float3 _SubPos;
	float _SubViewDepth;

	float4 _LeadColorBelow;
	float4 _MidColorBelow;
	float4 _TrailColorBelow;
	float _BelowOffset;
	float _CutoffTreshold;

	float4 scannerColor(float depth, float zDepth, float dist, float scanDist, float scanWidth, float offset, float3 currentScanPos)
	{
		half4 edge = half4(0, 0, 0, 0);
		float4 scannerCol = float4(0,0,0,0);
		float colorFade = (1 - dist / _MaxScanDistance);

		if (dist < (scanDist - offset) && dist > (scanDist - offset) - scanWidth && depth < 1 && scanDist - offset <= _MaxScanDistance && scanDist > offset)
		{
			float diff = 1 - (scanDist - offset - dist) / (scanWidth);
			float4 aboveColor = lerp(_TrailColor, lerp(_MidColor, _LeadColor, pow(diff, _LeadSharp)), diff);
			float4 belowColor = lerp(_TrailColorBelow, lerp(_MidColorBelow, _LeadColorBelow, pow(diff, _LeadSharp)), diff);

			if (_PerspectiveType == 0 || _PerspectiveType == 2)
			{
				if (currentScanPos.y >= _SubPos.y - _BelowOffset - _CutoffTreshold && currentScanPos.y <= _SubPos.y - _BelowOffset + _CutoffTreshold)
				{
					float gradientRange = 2 * _CutoffTreshold;
					float gradientDist = distance(currentScanPos.y, _SubPos.y - _BelowOffset + _CutoffTreshold);
					float gradientDiff = gradientDist / gradientRange;
					scannerCol = lerp(aboveColor, belowColor, gradientDiff);
				}
				else if (currentScanPos.y >= _SubPos.y - _BelowOffset)
				{
					scannerCol = aboveColor;
				}
				else
				{
					scannerCol = belowColor;
				}
			}
			else if (_PerspectiveType == 1)
			{
				if (zDepth <= _SubViewDepth + _BelowOffset + _CutoffTreshold && zDepth >= _SubViewDepth + _BelowOffset - _CutoffTreshold)
				{
					float gradientRange = 2 * _CutoffTreshold;
					float gradientDist = distance(zDepth, _SubViewDepth + _BelowOffset - _CutoffTreshold);
					float gradientDiff = gradientDist / gradientRange;
					scannerCol = lerp(aboveColor, belowColor, gradientDiff);
				}
				else if (zDepth <= _SubViewDepth + _BelowOffset)
				{
					scannerCol = aboveColor;
				}
				else
				{
					scannerCol = belowColor;
				}
			}

			return scannerCol *= diff * colorFade;
		}

		return float4(0, 0, 0, 0);
	}

    float4 FullScreenPass(VertOut i) : SV_Target
    {
        UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
        float depth = LoadCameraDepth(i.vertex.xy);
        PositionInputs posInput = GetPositionInput(i.vertex.xy, _ScreenSize.zw, depth, UNITY_MATRIX_I_VP, UNITY_MATRIX_V);

		float zDepth = posInput.linearDepth;
        float3 viewDirection = GetWorldSpaceNormalizeViewDir(posInput.positionWS);
        float4 color = float4(0.0, 0.0, 0.0, 0.0);

        // Load the camera color buffer at the mip 0 if we're not at the before rendering injection point
        if (_CustomPassInjectionPoint != CUSTOMPASSINJECTIONPOINT_BEFORE_RENDERING)
            color = float4(CustomPassLoadCameraColor(i.vertex.xy, 0), 1);

        // Add your custom pass code here
		half4 scannerCol = half4(0, 0, 0, 0);
		half4 secondScannerCol = half4(0, 0, 0, 0);

		float dist = distance(posInput.positionWS + _WorldSpaceCameraPos, _WorldSpaceScannerPos);
		float subDist = distance(posInput.positionWS + _WorldSpaceCameraPos, _SubsequentWorldSpaceScannerPos);
		
		float3 currentScanPos = posInput.positionWS + _WorldSpaceCameraPos;

		float totalOffset = _ScanDistanceOffset + _ScanWidth;
		scannerCol = scannerColor(depth, zDepth,  dist, _ScanDistance, _ScanWidth, 0, currentScanPos);
		secondScannerCol = scannerColor(depth, zDepth, subDist, _ScanDistance, _SubsequentScanWidth, totalOffset, currentScanPos);

		float4 scannerCols = scannerCol + secondScannerCol;

		return (color + scannerCols);
    }

    ENDHLSL

    SubShader
    {
        Pass
        {
            Name "Custom Pass 0"

            ZWrite Off
            ZTest Always
            Blend SrcAlpha OneMinusSrcAlpha
            Cull Off

            HLSLPROGRAM
                #pragma fragment FullScreenPass
            ENDHLSL
        }
    }
    Fallback Off
}
