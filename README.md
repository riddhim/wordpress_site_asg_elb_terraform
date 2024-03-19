Hello there!!

This terraform template is used to a launch wordpress webserver with a load balancer and a Auto scaling group fro the purpose of High Availibility.

It uses multi availibility zone.

Note : To make this tempate use in free tier, I have not implemented any ELB and R53/domain/cert related resources and configuration, also for the purpose of the project, in demo I have used single AZ.

Please find the below outcomes:

Before:


![bf_vpc1](https://github.com/riddhim/wordpress_site_asg_elb_terraform/assets/46811067/ede1a235-ee16-465c-b5e8-375f072f74ff)


![bf_asg](https://github.com/riddhim/wordpress_site_asg_elb_terraform/assets/46811067/79972da7-7720-480b-9cf0-c2a9c0401be4)

![bf_instances](https://github.com/riddhim/wordpress_site_asg_elb_terraform/assets/46811067/960f1823-3d83-412b-8715-57781717887d)

![bf_ec2_asg](https://github.com/riddhim/wordpress_site_asg_elb_terraform/assets/46811067/580a26f3-e60e-4707-85fb-1de83dff30c3)



After:

![af_asg](https://github.com/riddhim/wordpress_site_asg_elb_terraform/assets/46811067/269725f8-eba7-4426-b64a-056ff2ea749d)

![af_asg2](https://github.com/riddhim/wordpress_site_asg_elb_terraform/assets/46811067/97e1c4f4-eca9-415e-bbe3-aed30e8e3f44)

![af_subnet](https://github.com/riddhim/wordpress_site_asg_elb_terraform/assets/46811067/2be403bf-1f7c-4bf4-8128-65f69ae091a2)

![af_sg](https://github.com/riddhim/wordpress_site_asg_elb_terraform/assets/46811067/e8a6e833-1e61-4fff-b0c5-f265a80090dd)


![af_vpc1](https://github.com/riddhim/wordpress_site_asg_elb_terraform/assets/46811067/a75119dd-1bfa-4c06-8afa-35d3b5059adb)



Demo:

![wp](https://github.com/riddhim/wordpress_site_asg_elb_terraform/assets/46811067/78e718d3-786a-41f3-9649-951d3999cccc)

Regards,
Riddhi
