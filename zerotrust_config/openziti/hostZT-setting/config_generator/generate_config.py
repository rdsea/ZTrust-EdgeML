import yaml
from jinja2 import Environment, FileSystemLoader
import os
import argparse

# Set up paths
SCRIPT_DIR = os.path.abspath(os.path.dirname(__file__))
INPUT_FILE = os.path.join(SCRIPT_DIR, "variable_input.yml")
LOCAL_INPUT_FILE = os.path.join(SCRIPT_DIR, "variable_input.local.yml") # New local input file
TEMPLATE_DIR = os.path.join(SCRIPT_DIR, "..", "templates") # Corrected template directory path

# Parse command-line arguments
parser = argparse.ArgumentParser(description="Generate configuration files from templates.")
parser.add_argument("--output_dir", default=os.path.join(SCRIPT_DIR, ".."),
                    help="Root directory for generated output files.")
args = parser.parse_args()

OUTPUT_ROOT_DIR = args.output_dir

# Load data from YAML file
with open(INPUT_FILE, 'r') as f:
    config = yaml.safe_load(f)

# Load local override data if it exists
if os.path.exists(LOCAL_INPUT_FILE):
    with open(LOCAL_INPUT_FILE, 'r') as f:
        local_config = yaml.safe_load(f)
    # Merge local_config into config, overriding existing values
    # This handles nested dictionaries as well
    def deep_merge(base, new):
        for k, v in new.items():
            if isinstance(v, dict) and k in base and isinstance(base[k], dict):
                base[k] = deep_merge(base[k], v)
            else:
                base[k] = v
        return base
    config = deep_merge(config, local_config)

# Set up Jinja2 environment
env = Environment(loader=FileSystemLoader(TEMPLATE_DIR))

# --- Files to generate and their new output paths ---
files_to_generate = {
    "cloud_main_tf.tmpl": "cloud/main.tf",
    "scripts_setup_sensor_edge.sh.tmpl": "scripts/script_settup_sensor_edge.sh",
    "scripts_cleaning.sh.tmpl": "scripts/cleaning.sh",
    "scripts_pkill_all_zt_tunnel.sh.tmpl": "scripts/pkill_all_zt_tunnel.sh",
    "edge_create_id_entities.sh.tmpl": "edge/create_id_entities.sh",
    "edge_setup_app.sh.tmpl": "edge/setup_edge_app.sh",
    "edge_setup_router.sh.tmpl": "edge/setup_edge_router.sh",
    "sensor_setup_sensor.sh.tmpl": "sensor/setup_sensor.sh"
}

# Generate files based on the new structure
for template_name, relative_output_path in files_to_generate.items():
    template = env.get_template(template_name)
    rendered_content = template.render(config)
    output_file = os.path.join(OUTPUT_ROOT_DIR, relative_output_path)

    # Create parent directories if they don't exist
    os.makedirs(os.path.dirname(output_file), exist_ok=True)

    with open(output_file, 'w') as f:
        f.write(rendered_content)
    print(f"Successfully generated {output_file}")

# Generate shell scripts for VMs (these also go into the new 'cloud' folder)
# Note: The template names here need to be updated to reflect the new naming convention
vm_script_mapping = {
    "ziti-cloud-init.sh": "cloud_ziti_cloud_init.sh.tmpl",
    "ziti-mq-init.sh": "cloud_ziti_mq_init.sh.tmpl",
    "ziti-db-init.sh": "cloud_ziti_db_init.sh.tmpl"
}

for vm in config.get("vms", []):
    original_script_name = vm.get("provisioner_script")
    script_template_name = vm_script_mapping.get(original_script_name)

    if script_template_name:
        template = env.get_template(script_template_name)
        rendered_script = template.render(config)

        script_output_name = "cloud/" + original_script_name # Output name remains the same
        output_file = os.path.join(OUTPUT_ROOT_DIR, script_output_name)

        # Create parent directories if they don't exist
        os.makedirs(os.path.dirname(output_file), exist_ok=True)

        with open(output_file, 'w') as f:
            f.write(rendered_script)
        print(f"Successfully generated {output_file}")
    else:
        print(f"Warning: No template mapping found for {original_script_name}. Skipping.")