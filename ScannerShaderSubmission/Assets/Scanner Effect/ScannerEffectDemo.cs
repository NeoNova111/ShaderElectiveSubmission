using UnityEngine;
using System.Collections;
using UnityEngine.UI;

[ExecuteInEditMode]
public class ScannerEffectDemo : MonoBehaviour
{
	public Material EffectMaterial;
	public float ScanDistance;
    public float scanSpeed = 10;

	private Camera _camera;
    private float offset;

    public Transform origin;

    bool _scanning;
    bool setSubsequent;
    float maxScanCooldown;
    float maxScanDistance;

    Plane cameraPlane;

    void Start()
	{
        cameraPlane = new Plane();

        offset = EffectMaterial.GetFloat("_ScanWidth") + EffectMaterial.GetFloat("_ScanDistanceOffset");
        maxScanDistance = EffectMaterial.GetFloat("_MaxScanDistance") + EffectMaterial.GetFloat("_ScanDistanceOffset") + EffectMaterial.GetFloat("_ScanWidth");
        maxScanCooldown = maxScanDistance / scanSpeed;
    }

    void Update()
    {
        //if (submarineMovement.instance && submarineMovement.instance.GetCurrentRoom())
        //{
        //    switch (submarineMovement.instance.GetCurrentRoom().perspective)
        //    {
        //        case CameraPerspective.TOPDOWN:
        //            EffectMaterial.SetFloat("_PerspectiveType", 0);
        //            break;
        //        case CameraPerspective.SIDE:
        //            EffectMaterial.SetFloat("_PerspectiveType", 1);
        //            break;
        //        case CameraPerspective.POV:
        //            EffectMaterial.SetFloat("_PerspectiveType", 2);
        //            break;
        //    }
        //}

        cameraPlane.SetNormalAndPosition(transform.forward, transform.position);

        EffectMaterial.SetFloat("_SubViewDepth", cameraPlane.GetDistanceToPoint(origin.position));
        EffectMaterial.SetVector("_SubPos", origin.position);

        if (_scanning)
        {
            ScanDistance += scanSpeed * Time.deltaTime;
        }

        if (Input.GetKeyDown(KeyCode.C) && !_scanning)
		{
            StartScan();
        }

        if(ScanDistance >= offset && !setSubsequent)
        {
            EffectMaterial.SetVector("_SubsequentWorldSpaceScannerPos", origin.position);
            setSubsequent = true;
        }

        EffectMaterial.SetFloat("_ScanDistance", ScanDistance);
        EffectMaterial.SetTexture("_MainTex", _camera.activeTexture);

        //maybe move into coroutine for less calls
        if (_scanning && EffectMaterial.GetFloat("_ScanDistance") >= maxScanDistance)
            _scanning = false;
    }

	void OnEnable()
	{
		_camera = GetComponent<Camera>();
		_camera.depthTextureMode = DepthTextureMode.Depth;
	}

    void StartScan()
    {
        _scanning = true;
        setSubsequent = false;
        ScanDistance = 1;
        EffectMaterial.SetVector("_WorldSpaceScannerPos", origin.position);      //moved to allow for doppler effect
    }

    public void StopScan()
    {
        _scanning = false;
        ScanDistance = 0;
    }
}
