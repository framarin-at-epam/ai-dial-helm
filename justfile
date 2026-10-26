install-oc-cli:
    @echo "Installing OpenShift CLI..."
    @curl -L https://mirror.openshift.com/pub/openshift-v4/clients/oc/latest/linux/oc.tar.gz -o oc.tar.gz
    @tar -xzf oc.tar.gz
    @sudo mv oc /usr/local/bin/
    @sudo mv kubectl /usr/local/bin/
    @rm oc.tar.gz
    @echo "OpenShift CLI installed successfully."

install-aws-cli:
    @echo "Installing AWS CLI..."
    @curl -fsSL https://awscli.amazonaws.com/v2/install.sh | bash
    @echo "AWS CLI installed successfully."

install-rosa-cli:
    @echo "Installing ROSA CLI..."
    @curl -L https://mirror.openshift.com/pub/cgw/rosa/latest/rosa-linux.tar.gz -o rosa.tar.gz
    @tar -xzf rosa.tar.gz
    @sudo mv rosa /usr/local/bin/rosa
    @rosa version
    @rosa completion fish > ~/.config/fish/completions/rosa.fish
    @rm rosa.tar.gz
    @sleep 2
    @fish

# Helm installation and utility commands
install-helm:
    @echo "Installing Helm..."
    @curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-4
    @chmod 700 get_helm.sh
    @./get_helm.sh
    @rm ./get_helm.sh
    @mkdir ./logs

aws-remote-login:
    @echo "Login to AWS Console..."
    @aws login --remote

rosa-remote-login:
    @echo "Login to ROSA..."
    rosa login --use-device-code

oc-login-to-cluster:
    @oc login -u cluster-admin -p <cluster-password> https://api.dia
    l.i9at.p3.openshiftapps.com:443

helm-uninstall-dial:
    @echo "Uninstalling DIAL..."
    @helm uninstall dial -n dial

helm-build-dependencies:
    @echo "Building Helm chart dependencies..."
    @helm dependency build ./charts/dial/
    @echo "Dependencies built successfully."

helm-install-local-dial-chart:
    @echo "Installing DIAL (local chart)..."
    @helm install -o yaml dial ./charts/dial/ -n dial -f ./deployment/tests/openshift/values.yaml > logs/output.yaml
    @echo "DIAL installed successfully."

helm-upgrade-local-dial-chart:
    @echo "Upgrading DIAL (local chart)..."
    @helm upgrade -o yaml dial ./charts/dial/ -n dial -f ./deployment/tests/openshift/values.yaml > logs/output.yaml
    #With namespace: helm upgrade -i -n dial -o yaml dial dial/dial -f ./deployment/tests/openshift/values.yaml > logs/output.yaml
    @echo "DIAL upgraded successfully."

oc-chat-port-forward:
    @echo "Chat port forwarding service..."
    @oc port-forward --address 0.0.0.0 svc/dial-chat 3000:80

oc-core-port-forward:
    @echo "Core port forwarding service..."
    @oc port-forward --address 0.0.0.0 svc/dial-core 8080:80

helm-install-local-dial-admin-chart:
    @echo "Installing DIAL Admin (local chart)..."
    @helm install dial-admin ./charts/dial-admin -n dial -f ./deployment/tests/openshift/dial-admin-values.yaml

helm-upgrade-local-dial-admin-chart:
    @echo "Upgrading DIAL Admin (local chart)..."
    @helm upgrade dial-admin ./charts/dial-admin -n dial -f ./deployment/tests/openshift/dial-admin-values.yaml

oc-admin-frontend-port-forward:
    @echo "Admin frontend port forwarding service..."
    @oc port-forward --address 0.0.0.0 svc/dial-admin-frontend 3000:80