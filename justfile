install-oc-cli:
    @echo "Installing OpenShift CLI..."
    @curl -L https://mirror.openshift.com/pub/openshift-v4/clients/oc/latest/linux/oc.tar.gz -o oc.tar.gz
    @tar -xzf oc.tar.gz
    @sudo mv oc /usr/local/bin/
    @sudo mv kubectl /usr/local/bin/
    @rm oc.tar.gz
    @echo "OpenShift CLI installed successfully."

kub-uninstall-dial:
    @echo "Uninstalling DIAL..."
    @helm uninstall dial
    @echo "DIAL uninstalled successfully."