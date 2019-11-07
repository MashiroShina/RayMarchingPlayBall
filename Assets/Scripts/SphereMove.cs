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
      //  mrb.AddForce(new Vector3(v, 0, -h) * Time.deltaTime*300, ForceMode.Force);
        mrb.angularVelocity = new Vector3(-h, 0, -v) * Time.deltaTime * 300;
    }
}
