import yaml
from jinja2 import Environment, FileSystemLoader
import os

# Set up paths
CWD = os.path.dirname(os.path.realpath(__file__))
INPUT_FILE = os.path.join(CWD, "variable_input.yml")
TEMPLATE_DIR = os.path.join(CWD, "../cloud-gcp")
OUTPUT_DIR = os.path.join(CWD, "../cloud-gcp")

# Load data from YAML file
with open(INPUT_FILE, "r") as f:
    config = yaml.safe_load(f)

# Set up Jinja2 environment
env = Environment(loader=FileSystemLoader(TEMPLATE_DIR))

# Generate main.tf
template = env.get_template("main.tf.tmpl")
rendered_template = template.render(config)
output_file = os.path.join(OUTPUT_DIR, "main.tf")
with open(output_file, "w") as f:
    f.write(rendered_template)
print(f"Successfully generated {output_file}")

# Generate shell scripts
for vm in config.get("vms", []):
    script_template_name = vm.get("provisioner_script") + ".tmpl"
    script_output_name = vm.get("provisioner_script")

    template = env.get_template(script_template_name)
    rendered_script = template.render(config)

    output_file = os.path.join(OUTPUT_DIR, script_output_name)
    with open(output_file, "w") as f:
        f.write(rendered_script)
    print(f"Successfully generated {output_file}")
