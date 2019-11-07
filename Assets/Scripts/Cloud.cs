using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode]
public class Cloud : SceneViewFilter
{
     [SerializeField] private Shader _shader;

    private Material _raymarchMat;
    public Material _raymarchMaterial
    {
        get
        {
            if (!_raymarchMat && _shader)
            {
                _raymarchMat = new Material(_shader);
                _raymarchMat.hideFlags = HideFlags.HideAndDontSave;
            }

            return _raymarchMat;
        }
    }

    private Camera _cam;

    public Camera _camera
    {
        get
        {
            if (!_cam)
            {
                _cam = GetComponent<Camera>();
            }

            return _cam;
        }
    }


    public Transform light;
    public Texture2D tex;
    public Transform obj1, obj2;
    public Vector4 CloudAndSphere,cloud2;
    
    public Transform[] _cloudRigi;
    Vector4[] Rigis;
    private void Start()
    {
        Rigis = new Vector4[_cloudRigi.Length];
        
    }
    private void OnRenderImage(RenderTexture src, RenderTexture dest)
    {
        if (!_raymarchMaterial)
        {
            Graphics.Blit(src, dest);
            return;
        }
        
        for (int i = 0; i < _cloudRigi.Length; i++)
        {
            Rigis[i] = new Vector4(_cloudRigi[i].position.x, _cloudRigi[i].position.y,
                _cloudRigi[i].position.z, _cloudRigi[i].localScale.x);
        }
       
        _raymarchMaterial.SetMatrix("_CamFrustum", CamFrustum(_camera));
        _raymarchMaterial.SetMatrix("_CamToWorld", _camera.cameraToWorldMatrix);

        RenderTexture.active = dest;
        _raymarchMaterial.SetTexture("_MainTex", src);
        
        _raymarchMat.SetInt("_cloudRigiNum", _cloudRigi.Length);
        _raymarchMaterial.SetVectorArray("_cloudRigi", Rigis);
        
        _raymarchMaterial.SetTexture("_NoiseTex", tex);
        _raymarchMaterial.SetVector("_LightDir",light ? light.forward : Vector3.down);
        _raymarchMaterial.SetVector("_CloudAndSphere", CloudAndSphere);
        _raymarchMaterial.SetVector("_Cloud2", cloud2);
        GL.PushMatrix();
        GL.LoadOrtho();
        _raymarchMaterial.SetPass(0);
        GL.Begin(GL.QUADS);

        //BL
        GL.MultiTexCoord2(0, 0.0f, 0.0f);
        GL.Vertex3(0.0f, 0.0f, 3.0f);//3.0f == 第三 row
        //BR
        GL.MultiTexCoord2(0, 1.0f, 0.0f);
        GL.Vertex3(1.0f, 0.0f, 2.0f);
        //TR
        GL.MultiTexCoord2(0, 1.0f, 1.0f);
        GL.Vertex3(1.0f, 1.0f, 1.0f);
        //TL
        GL.MultiTexCoord2(0, 0.0f, 1.0f);
        GL.Vertex3(0.0f, 1.0f, 0.0f);

        GL.End();
        GL.PopMatrix();
    }

    private Matrix4x4 CamFrustum(Camera cam)
    {
        Matrix4x4 frustum = Matrix4x4.identity;
        float fov = Mathf.Tan(cam.fieldOfView * 0.5f * Mathf.Deg2Rad);
        Vector3 goUp = Vector3.up * fov;
        Vector3 goRight = Vector3.right * fov * cam.aspect;

        Vector3 TL = (-Vector3.forward - goRight + goUp);
        Vector3 TR = (-Vector3.forward + goRight + goUp);
        Vector3 BR = (-Vector3.forward + goRight - goUp);
        Vector3 BL = (-Vector3.forward - goRight - goUp);

        frustum.SetRow(0, TL);
        frustum.SetRow(1, TR);
        frustum.SetRow(2, BR);
        frustum.SetRow(3, BL);
        return frustum;
    }

    private void Update()
    {
        CloudAndSphere.x = obj1.position.x;
        CloudAndSphere.y = obj1.position.y;
        CloudAndSphere.z = obj1.position.z;
        cloud2.x = obj2.position.x;
        cloud2.y = obj2.position.y;
        cloud2.z = obj2.position.z;
        
    }
}
