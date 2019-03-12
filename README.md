# Thrifty cluster

I began my journey to learning kubernetes with the $300 Google Cloud Platform
credits you get when signing up. Naturally, I tried to keep my usage low.
Ideally, I wanted to spread the $300 over the 12 months you have to spend it.
That gave me a budget of $25/month.
Unfortunately, this is difficult with cloud kubernetes. Firstly, a cloud
loadbalancer starts at $18/month, which would leave $7 to play with.

I decided I could use the free tier f1-micro instance (0.2 vCPU, 0.6GB memory)
to manage ingresses to the cluster. This is achieveable by designing
your traefik deployment to always run on the free node. Additionally,
at all times your node must be assigned a static IP, and the internal IP
of the node must be the `externalIP` of the traefik service.

The desire to keep these properties true was the reason I wrote bash script
above. There may be much nicer ways to do this but here you are.

