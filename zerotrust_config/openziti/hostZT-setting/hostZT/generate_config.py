import yaml
from jinja2 import Environment, FileSystemLoader
import os

# Set up paths
CWD = os.path.dirname(os.path.realpath(__file__))
INPUT_FILE = os.path.join(CWD, "variable_input.yml")
TEMPLATE_DIR = os.path.join(CWD, "..")
OUTPUT_DIR = os.path.join(CWD, "..")

# Load data from YAML file
with open(INPUT_FILE, 'r') as f:
    config = yaml.safe_load(f)

# Set up Jinja2 environment
env = Environment(loader=FileSystemLoader(TEMPLATE_DIR))

# --- Files to generate ---
files_to_generate = {
    "cloud-gcp/main.tf.tmpl": "cloud-gcp/main.tf",
    "script_settup_sensor_edge.sh.tmpl": "script_settup_sensor_edge.sh",
    "cleaning.sh.tmpl": "cleaning.sh",
    "pkill_all_zt_tunnel.sh.tmpl": "pkill_all_zt_tunnel.sh",
    "edge/create_id_entities.sh.tmpl": "edge/create_id_entities.sh",
    "edge/setup_edge_app.sh.tmpl": "edge/setup_edge_app.sh",
    "edge/setup_edge_router.sh.tmpl": "edge/setup_edge_router.sh",
    "sensor/setup_sensor.sh.tmpl": "sensor/setup_sensor.sh"
}

# Generate cloud-gcp and edge sensor scripts
for template_name, output_name in files_to_generate.items():
    template = env.get_template(template_name)
    rendered_content = template.render(config)
    output_file = os.path.join(OUTPUT_DIR, output_name)
    with open(output_file, 'w') as f:
        f.write(rendered_content)
    print(f"Successfully generated {output_file}")

# Generate shell scripts for VMs
for vm in config.get("vms", []):
    script_template_name = "cloud-gcp/" + vm.get("provisioner_script") + ".tmpl"
    script_output_name = "cloud-gcp/" + vm.get("provisioner_script")

    template = env.get_template(script_template_name)
    rendered_script = template.render(config)

    output_file = os.path.join(OUTPUT_DIR, script_output_name)
    with open(output_file, 'w') as f:
        f.write(rendered_script)
    print(f"Successfully generated {output_file}")