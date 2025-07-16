import yaml
from jinja2 import Environment, FileSystemLoader

# Load YAML config
with open("variable_input.yml") as f:
    config = yaml.safe_load(f)

# Set up Jinja2 environment
env = Environment(loader=FileSystemLoader("."))

# Load and render template
template = env.get_template("exmple.tmpl")
rendered = template.render(**config)

# Output result
print(rendered)
