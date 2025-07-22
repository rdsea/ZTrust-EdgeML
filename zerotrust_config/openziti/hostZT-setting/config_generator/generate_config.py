import yaml
from jinja2 import Environment, FileSystemLoader, exceptions
import os
import argparse

# Set up paths
SCRIPT_DIR = os.path.abspath(os.path.dirname(__file__))
INPUT_FILE = os.path.join(SCRIPT_DIR, "variable_input.yml")
LOCAL_INPUT_FILE = os.path.join(SCRIPT_DIR, "variable_input.local.yml")
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

    # --- Transform ziti_config for template compatibility ---
    # if "ziti_config" in config:
    #     original_ziti_config = config.get("ziti_config", {})
    #     transformed_ziti_config = {}
    #
    #     # Flatten ctrl config from cloud_ctrl
    #     ctrl_data = original_ziti_config.get("ctrl", {}).get("cloud_ctrl", {})
    #     transformed_ziti_config.update(ctrl_data)
    #
    #     # Flatten router config from cloud_router and edge_router
    #     router_data = original_ziti_config.get("router", {})
    #
    #     # Preserve lists for cloud_router and edge_router
    #     router_data = original_ziti_config.get("router", {})
    #     cloud_routers = router_data.get("cloud_router", [])
    #     edge_routers = router_data.get("edge_router", [])
    #
    #     # Assign these as-is (do not flatten)
    #     transformed_ziti_config["cloud_routers"] = cloud_routers
    #     transformed_ziti_config["edge_routers"] = edge_routers
    #
    #     # cloud_router_data = router_data.get("cloud_router", {})
    #     # if cloud_router_data:
    #     #     transformed_ziti_config.update(cloud_router_data)
    #     #     transformed_ziti_config["cloud_router_enabled"] = True
    #
    #     # edge_router_data = router_data.get("edge_router", {})
    #     # if edge_router_data:
    #     #     transformed_ziti_config.update(edge_router_data)
    #     #     transformed_ziti_config["edge_router_enabled"] = True
    #
    #     config["ziti_config"] = transformed_ziti_config
    # --- End Transformation ---

    # Set up Jinja2 environment
    env = Environment(loader=FileSystemLoader(TEMPLATE_DIR))

    # --- Files to generate and their new output paths ---
    files_to_generate = {
        "common.sh.tmpl": "scripts/common.sh",
        "cloud_main_tf.tmpl": "cloud/main.tf",
        "scripts_setup_sensor_edge.sh.tmpl": "scripts/script_settup_sensor_edge.sh",
        "scripts_cleaning.sh.tmpl": "scripts/cleaning.sh",
        "scripts_pkill_all_zt_tunnel.sh.tmpl": "scripts/pkill_all_zt_tunnel.sh",
        "edge_setup_app.sh.tmpl": "edge/setup_edge_app.sh",
        "docker_compose.yml.tmpl": "edge/docker-compose.yml.tmpl",
        "sensor_setup_sensor.sh.tmpl": "sensor/setup_sensor.sh",
        "scripts_run_experiment_sensor.sh.tmpl": "scripts/run_experiment_sensor.sh",
    }

    ziti_config = config.get("ziti_config", {})
    ctrls = ziti_config.get("ctrl", {})
    routers = ziti_config.get("router", {})

    for ctrl_name, ctrl_data in ctrls.items():
        router_info = ctrl_data.get("router")
        if not router_info:
            continue  # skip if controller doesn't have router info

        router_id = router_info.get("id")
        if not router_id:
            continue  # malformed router entry

        # check if router with that ID exists in router config
        router_exists = any(
            r.get("id") == router_id
            for rlist in routers.values()
            for r in (rlist if isinstance(rlist, list) else [rlist])
        )

        if router_exists:
            files_to_generate["edge_create_id_entities.sh.tmpl"] = (
                "edge/create_id_entities.sh"
            )
            break  # or continue if want to allow multiple pairs

    for template_name, relative_output_path in files_to_generate.items():
        generate_file(env, config, template_name, relative_output_path, OUTPUT_ROOT_DIR)

    # Generate shell scripts for VMs (these also go into the new 'cloud' folder)
    vm_script_mapping = {
        "ziti-cloud-init.sh": "cloud_ziti_cloud_init.sh.tmpl",
        "ziti-mq-init.sh.tmpl": "cloud_ziti_mq_init.sh.tmpl",
        "ziti-db-init.sh.tmpl": "cloud_ziti_db_init.sh.tmpl",
        "ziti-jaeger-init.sh": "cloud_ziti_jaeger_init.sh.tmpl",
    }

    for vm in config.get("vms", []):
        original_script_name = vm.get("provisioner_script")
        script_template_name = vm_script_mapping.get(original_script_name)

        vm_config = deep_merge(config.copy(), {"vm": vm})

        if script_template_name:
            relative_output_path = os.path.join("cloud/", original_script_name)
            generate_file(
                env,
                vm_config,
                script_template_name,
                relative_output_path,
                OUTPUT_ROOT_DIR,
            )
        else:
            print(
                f"Warning: No template mapping found for {original_script_name}. Skipping."
            )

    # --- cloud router generation, but require specific IP ---
    for router_cloud in (
        config.get("ziti_config", {}).get("router", []).get("cloud_router", {})
    ):
        router_id = router_cloud["id"]
        router_config = deep_merge(config.copy(), {"router": router_cloud})
        script_name = f"setup_{router_id}.sh"
        generate_file(
            env,
            router_config,
            "edge_setup_router.sh.tmpl",
            f"cloud/{script_name}",
            OUTPUT_ROOT_DIR,
        )

    # --- edge router generation, but require specific IP ---
    for router in (
        config.get("ziti_config", {}).get("router", []).get("edge_router", {})
    ):
        router_id = router["id"]
        router_config = deep_merge(config.copy(), {"router": router})
        script_name = f"setup_{router_id}.sh"
        generate_file(
            env,
            router_config,
            "edge_setup_router.sh.tmpl",
            f"edge/{script_name}",
            OUTPUT_ROOT_DIR,
        )

    # --- Copy docker-compose.template.yml ---
    # docker_compose_template_source = os.path.join(
    #     SCRIPT_DIR, config.get("edge_deployment", {}).get("dockercompose_app", {})
    # )
    # docker_compose_template_destination = os.path.join(
    #     OUTPUT_ROOT_DIR, "edge", "docker-compose.template.yml"
    # )
    #
    # if os.path.exists(docker_compose_template_source):
    #     try:
    #         with open(docker_compose_template_source, "r") as src_file:
    #             content = src_file.read()
    #         os.makedirs(
    #             os.path.dirname(docker_compose_template_destination), exist_ok=True
    #         )
    #         with open(docker_compose_template_destination, "w") as dest_file:
    #             dest_file.write(content)
    #         print(
    #             f"Successfully copied {docker_compose_template_source} to {docker_compose_template_destination}"
    #         )
    #     except Exception as e:
    #         print(f"Error copying {docker_compose_template_source}: {e}")
    # else:
    #     print(
    #         f"Warning: Source file not found: {docker_compose_template_source}. Skipping copy."
    #     )
