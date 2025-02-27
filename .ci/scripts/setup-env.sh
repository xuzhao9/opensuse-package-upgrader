#!/usr/bin/env bash

# install dependencies in the container
zypper in -y \
    osc build sudo obs-service-download_files obs-service-recompress \
    obs-service-set_version obs-service-source_validator obs-service-tar_scm \
    obs-service-verify_file obs-service-format_spec_file jq awk curl rpm git \
    rustup go1.20

# download and setup rust
rustup default stable

# write to obs credentials
mkdir -p $HOME/.config/osc
cat<<EOF > $HOME/.config/osc/oscrc
# Generated by opensuse-package-upgrader
[general]
apiurl=https://api.opensuse.org

[https://api.opensuse.org]
user=${OSC_USERNAME}
pass=${OSC_PASSWD}
credentials_mgr_class=osc.credentials.PlaintextConfigFileCredentialsManager
EOF

osc person
echo "OBS login successful"
