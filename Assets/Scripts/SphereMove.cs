using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class SphereMove : MonoBehaviour
{
    private Rigidbody mrb;

    // Start is called before the first frame update
    void Start()
    {
        mrb = GetComponent<Rigidbody>();
    }

    // Update is called once per frame
    void Update()
    {
        float h = Input.GetAxis("Horizontal");
        float v = Input.GetAxis("Vertical");
        if (this.transform.CompareTag("Untagged"))
        {
            mrb.angularVelocity = new Vector3(-h, 0, -v) * Time.deltaTime * 300;
        }
        this.transform.Rotate(new Vector3(h*Time.deltaTime*20,0,v*Time.deltaTime*20));
    }
}
