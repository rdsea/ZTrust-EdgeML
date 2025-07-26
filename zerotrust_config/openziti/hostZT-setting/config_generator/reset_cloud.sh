#!/bin/bash
# set -e # Exit immediately on error
#
# cd cloud
# terraform destroy -auto-approve
#
# cd ..
# python generation_config.py --output_dir .
#
# cd cloud
# terraform apply -auto-approve
#
# #!/bin/bash
# set -e  # Exit on error

cd cloud
terraform destroy -auto-approve
cd ..

# Check script
if [[ ! -f generate_config.py ]]; then
  echo "generate_config.py not found in $(pwd)"
  exit 1
fi

# Run script using specific Python if needed
python generate_config.py --output_dir .

cd cloud
terraform apply -auto-approve
