## Log into the cluster

Open Cloudshell and conenct to the cluster
aws eks update-kubeconfig --name dev-eks-cluster --region us-east-1

Validate system pods

Check load balancer
kubectl get pods -n kube-system \
  -l app.kubernetes.io/name=aws-load-balancer-controller

Check external dns
kubectl get pods -n kube-system \
  -l app.kubernetes.io/name=external-dns

