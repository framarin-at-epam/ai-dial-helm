# Override per target, e.g.: just helm-upgrade-local-dial-chart values=deployment/tests/rosa/values.yaml
values := "deployment/tests/local/values.yaml"
admin_values := "deployment/tests/local/dial-admin-values.yaml"

# Helm installation and utility commands
install-helm:
    @echo "Installing Helm..."
    @curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-4
    @chmod 700 get_helm.sh
    @./get_helm.sh
    @rm ./get_helm.sh
    @mkdir -p ./logs

helm-uninstall-dial:
    @echo "Uninstalling DIAL..."
    @helm uninstall dial -n dial

helm-build-dependencies:
    @echo "Building Helm chart dependencies..."
    @helm dependency build ./charts/dial/
    @echo "Dependencies built successfully."

helm-install-local-dial-chart values=values:
    @echo "Installing DIAL (local chart)..."
    @helm install -o yaml dial ./charts/dial/ -n dial -f {{values}} > logs/output.yaml
    @echo "DIAL installed successfully."

helm-upgrade-local-dial-chart values=values:
    @echo "Upgrading DIAL (local chart)..."
    @helm upgrade -o yaml dial ./charts/dial/ -n dial -f {{values}} > logs/output.yaml
    @echo "DIAL upgraded successfully."

helm-install-local-dial-admin-chart values=admin_values:
    @echo "Installing DIAL Admin (local chart)..."
    @helm install dial-admin ./charts/dial-admin -n dial -f {{values}}

helm-upgrade-local-dial-admin-chart values=admin_values:
    @echo "Upgrading DIAL Admin (local chart)..."
    @helm upgrade dial-admin ./charts/dial-admin -n dial -f {{values}}

core-port-forward:
    @echo "Core port forwarding service..."
    @kubectl port-forward --address 0.0.0.0 svc/dial-core 8080:80

chat-port-forward:
    @echo "Chat port forwarding service..."
    @kubectl port-forward --address 0.0.0.0 svc/dial-chat 3000:80

admin-frontend-port-forward:
    @echo "Admin frontend port forwarding service..."
    @kubectl port-forward --address 0.0.0.0 svc/dial-admin-frontend 3000:80
