using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[RequireComponent(typeof(Camera))]
public class MeshDrawer : MonoBehaviour
{
    public Material waterMat;                           // Material for the water surface
    public Material caustics;                           // Material for caustics effect
    public GameObject waterPlane;                       // The water plane game object
    Camera cam;                                         // Reference to the camera component
    [Header("Mesh Generation")]
    public Mesh mesh;                                   // Mesh for the water surface
    [Range(0, 2000)]
    [SerializeField] int meshResolution;                // Resolution of the water mesh
    Vector2[] uvs;                                      // UV coordinates for the water mesh vertices

    [Header("UnderWaterEffect")]
    public MeshFilter quadMeshFilter;                    // Mesh filter for the quad mesh used in underwater effect
    public Mesh quadMesh;                                // Quad mesh used in underwater effect
    public Material transitionMat;                       // Material for the underwater transition effect
    [Range(0, 100)]
    public int quadRes;                                  // Resolution of the quad mesh
    Vector2[] uvsQuad;                                   // UV coordinates for the quad mesh vertices
    int width;                                           // Width of the screen
    int height;                                          // Height of the screen
    RenderTexture colorBuffer;                           // Render texture for color buffer
    RenderTexture depthBuffer;                           // Render texture for depth buffer

    private void Start()
    {
        cam = GetComponent<Camera>();
        cam.depthTextureMode = cam.depthTextureMode | DepthTextureMode.DepthNormals;

        //----------Create Water Mesh--------------
        mesh = new Mesh();
        Vector3[] vertices = new Vector3[(meshResolution + 1) * (meshResolution + 1)];

        uvs = new Vector2[vertices.Length];
        for (int i = 0, x = 0; x <= meshResolution; x++)
        {
            for (int z = 0; z <= meshResolution; z++)
            {
                // Calculate vertex positions and UV coordinates
                vertices[i] = new Vector3((float)z / (float)meshResolution - .5f, 0, (float)x / (float)meshResolution - .5f);
                uvs[i] = new Vector2((float)x / meshResolution, (float)z / meshResolution);
                i++;
            }
        }

        int[] triangles = new int[meshResolution * meshResolution * 6];

        int vert = 0;
        int tris = 0;

        for (int z = 0; z < meshResolution; z++)
        {
            for (int x = 0; x < meshResolution; x++)
            {
                // Define triangles for the mesh
                triangles[tris + 0] = vert + 0;
                triangles[tris + 1] = vert + meshResolution + 1;
                triangles[tris + 2] = vert + 1;
                triangles[tris + 3] = vert + 1;
                triangles[tris + 4] = vert + meshResolution + 1;
                triangles[tris + 5] = vert + meshResolution + 2;

                vert++;
                tris += 6;
            }
            vert++;
        }

        mesh.indexFormat = UnityEngine.Rendering.IndexFormat.UInt32;
        mesh.vertices = vertices;
        mesh.triangles = triangles;
        mesh.uv = uvs;
        mesh.RecalculateNormals();


        //---------------Quad-Mesh for Water Transition---------------
        quadMesh = new Mesh();
        Vector3[] verticesQuad = new Vector3[(quadRes + 1) * (quadRes + 1)];
        uvsQuad = new Vector2[verticesQuad.Length];
        for (int i = 0, x = 0; x <= 1; x++)
        {
            for (int z = 0; z <= quadRes; z++)
            {
                // Calculate vertex positions and UV coordinates for the quad mesh
                verticesQuad[i] = transform.InverseTransformPoint(cam.ViewportToWorldPoint(new Vector3((float)z / (float)quadRes, x, cam.nearClipPlane + 0.001f)));
                uvsQuad[i] = new Vector2((float)z / (float)quadRes, x);
                i++;
            }
        }
        int[] trianglesQuad = new int[quadRes * quadRes * 6];

        int vertquad = 0;
        int trisquad = 0;

        for (int z = 0; z < 1; z++)
        {
            for (int x = 0; x < quadRes; x++)
            {
                // Define triangles for the quad mesh
                trianglesQuad[trisquad + 0] = vertquad + 0;
                trianglesQuad[trisquad + 1] = vertquad + quadRes + 1;
                trianglesQuad[trisquad + 2] = vertquad + 1;
                trianglesQuad[trisquad + 3] = vertquad + 1;
                trianglesQuad[trisquad + 4] = vertquad + quadRes + 1;
                trianglesQuad[trisquad + 5] = vertquad + quadRes + 2;

                vertquad++;
                trisquad += 6;
            }
            vertquad++;
        }

        quadMesh.vertices = verticesQuad;
        quadMesh.triangles = trianglesQuad;
        quadMesh.uv = uvsQuad;
        quadMesh.RecalculateNormals();
        quadMeshFilter.mesh = quadMesh;

        //----------Change Target Buffers----------
        width = Screen.width;
        height = Screen.height;
        colorBuffer = new RenderTexture(Screen.width, Screen.height, 1, RenderTextureFormat.ARGBFloat);
        depthBuffer = new RenderTexture(Screen.width, Screen.height, 32, RenderTextureFormat.Depth);
        cam.SetTargetBuffers(colorBuffer.colorBuffer, depthBuffer.depthBuffer);
        transitionMat.SetTexture("_CameraDepthBuffer", depthBuffer);
        transitionMat.SetTexture("_BackGround", colorBuffer);

        waterPlane.GetComponent<MeshFilter>().mesh = mesh;
        waterPlane.GetComponent<MeshRenderer>().material = waterMat;
    }

    void UpdateQuad()
    {
        //-------Quad-Mesh-------
        Vector3[] verticesQuad = new Vector3[(quadRes + 1) * (quadRes + 1)];

        for (int i = 0, x = 0; x <= 1; x++)
        {
            for (int z = 0; z <= quadRes; z++)
            {
                // Calculate vertex positions for the quad mesh
                verticesQuad[i] = transform.InverseTransformPoint(cam.ViewportToWorldPoint(new Vector3((float)z / (float)quadRes, x, cam.nearClipPlane + 0.0001f)));
                i++;
            }
        }

        quadMesh.vertices = verticesQuad;
        quadMesh.RecalculateNormals();
    }

    private void Update()
    {
        if (Screen.width != width || Screen.height != height)
        {
            // Update render textures and quad mesh when screen size changes
            if (colorBuffer)
                Destroy(colorBuffer);
            if (depthBuffer)
                Destroy(depthBuffer);
            colorBuffer = new RenderTexture(Screen.width, Screen.height, 1, RenderTextureFormat.ARGBFloat);
            depthBuffer = new RenderTexture(Screen.width, Screen.height, 32, RenderTextureFormat.Depth);
            cam.SetTargetBuffers(colorBuffer.colorBuffer, depthBuffer.depthBuffer);
            transitionMat.SetTexture("_CameraDepthBuffer", depthBuffer);
            transitionMat.SetTexture("_BackGround", colorBuffer);

            UpdateQuad();
            width = Screen.width;
            height = Screen.height;
        }
        waterMat.SetVector("_TransformScale", new Vector2(waterPlane.transform.localScale.x, waterPlane.transform.localScale.z));
        waterMat.SetVector("_TransformPosition", waterPlane.transform.position);
        waterMat.SetMatrix("_ViewToWorld", cam.cameraToWorldMatrix);

        caustics.SetMatrix("_ViewToWorld", cam.cameraToWorldMatrix);
    }
}
