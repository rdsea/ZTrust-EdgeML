import yaml
from jinja2 import Environment, FileSystemLoader, exceptions
import os
import argparse
import yaml

# Set up paths
SCRIPT_DIR = os.path.abspath(os.path.dirname(__file__))
INPUT_FILE = os.path.join(SCRIPT_DIR, "variable_input_gke.yml")
LOCAL_INPUT_FILE = os.path.join(SCRIPT_DIR, "variable_input_gke.local.yml")
TEMPLATE_DIR = os.path.join(SCRIPT_DIR, "..", "templates")


# --- Helper function for deep merging dictionaries ---
def deep_merge(base, new):
    for k, v in new.items():
        if isinstance(v, dict) and k in base and isinstance(base[k], dict):
            base[k] = deep_merge(base[k], v)
        else:
            base[k] = v
    return base


# --- Helper function to generate a single file ---
def generate_file(env, config, template_name, relative_output_path, output_root_dir):
    try:
        template = env.get_template(template_name)
        rendered_content = template.render(**config)
        output_file = os.path.join(output_root_dir, relative_output_path)

        os.makedirs(os.path.dirname(output_file), exist_ok=True)
        with open(output_file, "w") as f:
            f.write(rendered_content)
        print(f"Successfully generated {output_file}")
    except exceptions.TemplateNotFound:
        print(
            f"Error: Template '{template_name}' not found in '{TEMPLATE_DIR}'. Skipping."
        )
    except Exception as e:
        print(f"Error generating {relative_output_path} from {template_name}: {e}")


# --- Main execution logic ---
if __name__ == "__main__":
    # Parse command-line arguments
    parser = argparse.ArgumentParser(
        description="Generate configuration files from templates."
    )
    parser.add_argument(
        "--output_dir",
        default=os.path.join(SCRIPT_DIR, ".."),
        help="Root directory for generated output files.",
    )
    args = parser.parse_args()

    OUTPUT_ROOT_DIR = args.output_dir

    # Load data from YAML file
    with open(INPUT_FILE, "r") as f:
        config = yaml.safe_load(f)

    # Load local override data if it exists
    if os.path.exists(LOCAL_INPUT_FILE):
        with open(LOCAL_INPUT_FILE, "r") as f:
            local_config = yaml.safe_load(f)
        config = deep_merge(config, local_config)

    # Set up Jinja2 environment
    env = Environment(loader=FileSystemLoader(TEMPLATE_DIR))

    # --- Files to generate and their new output paths ---
    files_to_generate = {
        "common.sh.tmpl": "scripts/common.sh",
        "gke_main_tf.tmpl": "gke/main.tf",
        "gke_script_setup_cluster.sh.tmpl": "scripts/gke_script_setup_cluster.sh",
        "gke_dns_configmap.yml.tmpl": "scripts/gke_dns_configmap.yml",
        "csc_main_tf.tmpl": "csc/main.tf",
        "csc_script_setup_cluster.sh.tmpl": "scripts/csc_script_setup_cluster.sh",
        "k3s_ansible_inventory.yml.tmpl": "k3s/k3s_ansible_inventory.local.yml",
        "k3s_edge_cluster.sh.tmpl": "k3s/k3s_edge_cluster.sh.tmpl",
        "k3s_edge_setup_router.sh.tmpl": "k3s/k3s_edge_setup_router.sh.tmpl",
        "k3s_ingress.yml.tmpl": "k3s/k3s_ingress.yml",
        "gke_script_firewal_check.sh.tmpl": "gke/gke_script_firewal_check.sh",
        # "gke_k3s_deployment.yml.tmpl": "k3s/k3s_deployment.yml",
        # "gke_k3s_deployment.yml.tmpl": "gke/gke_deployment.yml",
    }

    ctrl_advertise_name = (
        config.get("ziti_config", {})
        .get("ctrl", {})
        .get("cloud_ctrl", {})
        .get("ctrl_advertised_address")
    )
    print("ctrl name", ctrl_advertise_name)
    parts = ctrl_advertise_name.split(".")
    domain = ".".join(parts[-2:])
    print("domain ", domain)
    domain_config = deep_merge(config.copy(), {"custom_domain": domain})
    # routers = ziti_config.get("router", {})
    #
    # for ctrl_name, ctrl_data in ctrls.items():
    #     router_info = ctrl_data.get("router")
    #     if not router_info:
    #         continue  # skip if controller doesn't have router info
    #
    #     router_id = router_info.get("id")
    #     if not router_id:
    #         continue  # malformed router entry
    #
    #     # check if router with that ID exists in router config
    #     router_exists = any(
    #         r.get("id") == router_id
    #         for rlist in routers.values()
    #         for r in (rlist if isinstance(rlist, list) else [rlist])
    #     )
    #
    #     if router_exists:
    #         files_to_generate["edge_create_id_entities.sh.tmpl"] = (
    #             "edge/create_id_entities.sh"
    #         )
    #         break  # or continue if want to allow multiple pairs
    #
    for template_name, relative_output_path in files_to_generate.items():
        generate_file(
            env, domain_config, template_name, relative_output_path, OUTPUT_ROOT_DIR
        )

    services = config.get("edge_applications", [])

    # Split by location
    edge_services = [
        s
        for s in services
        if s.get("location") == "edge" and s.get("image") != "default"
    ]
    cloud_services = [
        s
        for s in services
        if s.get("location") == "cloud" and s.get("image") != "default"
    ]

    # Render both to separate files using the same template
    split_template = "gke_k3s_deployment.yml.tmpl"

    generate_file(
        env,
        {"services": edge_services},
        split_template,
        "k3s/edge_deployment.yml",  # Customize as needed
        OUTPUT_ROOT_DIR,
    )

    generate_file(
        env,
        {"services": cloud_services},
        split_template,
        "gke/cloud_deployment.yml",  # Customize as needed
        OUTPUT_ROOT_DIR,
    )

    #
    # # Generate shell scripts for VMs (these also go into the new 'cloud' folder)
    # vm_script_mapping = {
    #     "ziti-cloud-init.sh": "cloud_ziti_cloud_init.sh.tmpl",
    #     "ziti-mq-init.sh.tmpl": "cloud_ziti_mq_init.sh.tmpl",
    #     "ziti-db-init.sh.tmpl": "cloud_ziti_db_init.sh.tmpl",
    #     "ziti-jaeger-init.sh": "cloud_ziti_jaeger_init.sh.tmpl",
    # }
    #
    # for vm in config.get("vms", []):
    #     original_script_name = vm.get("provisioner_script")
    #     script_template_name = vm_script_mapping.get(original_script_name)
    #
    #     vm_config = deep_merge(config.copy(), {"vm": vm})
    #
    #     if script_template_name:
    #         relative_output_path = os.path.join("cloud/", original_script_name)
    #         generate_file(
    #             env,
    #             vm_config,
    #             script_template_name,
    #             relative_output_path,
    #             OUTPUT_ROOT_DIR,
    #         )
    #     else:
    #         print(
    #             f"Warning: No template mapping found for {original_script_name}. Skipping."
    #         )
    #
    # # --- cloud router generation, but require specific IP ---
    # for router_cloud in (
    #     config.get("ziti_config", {}).get("router", []).get("cloud_router", {})
    # ):
    #     router_id = router_cloud["id"]
    #     router_config = deep_merge(config.copy(), {"router": router_cloud})
    #     script_name = f"setup_{router_id}.sh"
    #     generate_file(
    #         env,
    #         router_config,
    #         "edge_setup_router.sh.tmpl",
    #         f"cloud/{script_name}",
    #         OUTPUT_ROOT_DIR,
    #     )
    #
    # # --- edge router generation, but require specific IP ---
    # for router in (
    #     config.get("ziti_config", {}).get("router", []).get("edge_router", {})
    # ):
    #     router_id = router["id"]
    #     router_config = deep_merge(config.copy(), {"router": router})
    #     script_name = f"setup_{router_id}.sh"
    #     generate_file(
    #         env,
    #         router_config,
    #         "edge_setup_router.sh.tmpl",
    #         f"edge/{script_name}",
    #         OUTPUT_ROOT_DIR,
    #     )
    #
    # rabbitmq_config = {}
    #
    # mongodb_config = {}
    # for vm in config.get("vms", []):
    #     if "rabbitmq_config" in vm:
    #         rabbitmq_config = {
    #             "url": vm["rabbitmq_config"].get("url", ""),
    #             "queue_name": vm["rabbitmq_config"].get("queue_name", ""),
    #             "username": vm["rabbitmq_config"].get("user", ""),
    #             "password": vm["rabbitmq_config"].get("pass", ""),
    #         }
    #     if "mongo_config" in vm:
    #         mongodb_config = {
    #             "url": vm["mongo_config"].get("url", ""),
    #             "username": vm["mongo_config"].get("user", ""),
    #             "password": vm["mongo_config"].get("pass", ""),
    #         }
    #
    # config_dict = {"rabbitmq": rabbitmq_config, "mongodb": mongodb_config}
    #
    # yaml_text = yaml.dump(config_dict, default_flow_style=False)
    #
    # rabbitmq_comment = ""
    #
    # lines = yaml_text.splitlines()
    # rabbitmq_start = lines.index("rabbitmq:")
    # mongodb_start = lines.index("mongodb:")
    #
    # rabbitmq_block = lines[rabbitmq_start + 1 : mongodb_start]
    # mongodb_block = lines[mongodb_start:]
    #
    # rabbitmq_block = ["  " + line for line in rabbitmq_block]
    #
    # final_yaml = (
    #     (rabbitmq_comment + "\n" if rabbitmq_comment else "")
    #     + "\n".join(rabbitmq_block)
    #     + "\n\n"
    #     + "\n".join(mongodb_block)
    # )
    # with open("cloud/config.yaml", "w") as f:
    #     f.write(final_yaml)
    #
    # print("Config written to config_output.yaml with correct indentation and comments.")
