# Terraform_Planner

This produces a [Docker image](https://hub.docker.com/r/eversc/terraform_planner/) 
that can be run periodically to run a `terraform plan`, and post the
resulting status code to Datadog.

Currently only [Google](https://www.terraform.io/docs/providers/google) and 
[Kubernetes](https://www.terraform.io/docs/providers/kubernetes) providers are
supported, though there's definitely scope for more to be added.

Only Github is supported, in terms of the repo where you hold your terraform
config.

## Environment Variables

| name        | required?           | default  | purpose |
| ------------- |:-------------:|:-----:|:-----:|
|`CONFIG_PATH`      | N | ./tf_planner.conf | Path to config file |
|`DD_API_KEY`      | y |  | Datadog API key |
|`DD_ENV`      | y |  | name of environment (used as a tag in Datadog metric) |
|`DD_METRIC_NAME`      | y |  | name of Datadog metric |
|`DD_TEAM`      | y |  | name of team (used as a tag in Datadog metric) |
|`GCP_PROJECT_NAME`      | n |  | name of GCP project the gke cluster is running in|
|`GCP_ZONE`      | n |  | name of GCP zone that the gke cluster is running in |
|`GIT_CLONE_STRING`      | y |  | ssh string used to clone a repo, e.g. `git@github.com:my_org/my_repo.git` |
|`GOOGLE_APPLICATION_CREDENTIALS`      | y |  | path to the service-account key.json |
|`K8S_CLUSTER_NAME`     | n |  | name of k8s cluster |
|`POST_COMMIT_WAIT_MINS`      | n | 10 | if a commit has been made to the git repo within this time, skip the run |
|`TF_INIT_ARGS`      | n | "" | args to supply the [terraform init command](https://www.terraform.io/docs/commands/init.html) |
|`TF_PATH`     | y |  |  |
|`TF_PLAN_ARGS`      | n | "" | args to supply the [terraform plan command](https://www.terraform.io/docs/commands/plan.html) |

Variables can also be pulled from a config file (default: `/etc/tf_planner.conf`)

E.g.:

```bash
DD_API_KEY=12345abcde
DD_ENV=prod
DD_METRIC_NAME=tf_plan
...
...
```

Variables from both config and env vars are joined. Config vars take precedence.

## Notes

* It's recommended to create a [Deploy Key](https://developer.github.com/v3/guides/managing-deploy-keys/#deploy-keys)
to give the `terraform_planner` access to your git repo.

* You'll need to drop the ssh key into `~/.ssh` (`/home/tf/.ssh`). The `plan.sh` 
script verifies github's public key fingerprint, and upon a successful check,
adds the key to `known_hosts`.

* The script won't ever be running `terraform apply`, so the service-account 
used should be locked down to read-only scopes for the resources it needs.

* If using the metric in Datadog Monitors with 'Notify if data is missing' 
enabled, it's recommended to set the 'missing data' threshold value in Datadog
to more than the `POST_COMMIT_WAIT_MINS` value. Otherwise, every time a commit
is made to the git repo, the missing data alert will be fired.

* Ensure the time window in the Datadog monitor alert condition is less than the
frequency of the `terraform_planner` run. This is to prevent the metric being 
included in two adjacent time chunks (meaning you would get a count of 2
if a status of 1 was outputted in subsequent runs).

* Contributions are very welcome (please branch or fork and raise PR).
