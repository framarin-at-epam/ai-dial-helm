rosa create cluster --cluster-name dial-cluster --domain-prefix dial \
    --create-admin-user --enable-autoscaling \
    --role-arn arn:aws:iam::354363695108:role/ManagedOpenShift-HCP-ROSA-Installer-Role \
    --support-role-arn arn:aws:iam::354363695108:role/ManagedOpenShift-HCP-ROSA-Support-Role \
    --worker-iam-role arn:aws:iam::354363695108:role/ManagedOpenShift-HCP-ROSA-Worker-Role \
    --operator-roles-prefix dial-cluster-oper --oidc-config-id 2tj8kprun92utqa5iket15jj50ghuni7 \
    --region us-east-2 --version 4.22.18 --compute-machine-type m8i-flex.large \
    --machine-cidr 10.0.0.0/16 --service-cidr 172.30.0.0/16 --pod-cidr 10.128.0.0/14 \
    --host-prefix 23 --default-ingress-private --min-replicas 2 --max-replicas 8 \
    --subnet-ids subnet-08e70e2e1a08aeed5,subnet-0d096ff42976a3a89,subnet-0ceed2392bdea76f8,subnet-026033a5a48444e08 \
    --notification-contacts framarin-at-epam --hosted-cp --billing-account 354363695108
    #--replicas 2
