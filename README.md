# terraform_planner

This produces a Docker image that can be run periodically to run a `terraform
plan`, and post the resulting status code to Datadog.

Currently only [Google](https://www.terraform.io/docs/providers/google) and 
[Kubernetes](https://www.terraform.io/docs/providers/kubernetes) providers are
supported, though there's definitely scope for more to be added.

## environment variables

| name        | required?           | default  | purpose |
| ------------- |:-------------:|:-----:|:-----:|
|`DD_API_KEY`      | y |  | Datadog API key |
|`ENV`      | y |  | name of environment (used as a tag in Datadog metric) |
|`GCP_PROJECT_NAME`      | y |  | name of GCP project |
|`GCP_ZONE`      | y |  | name of GCP zone that the k8s cluster is running in |
|`GIT_CLONE_STRING`      | y |  | ssh string used to clone a repo, e.g. `git@github.com:my_org/my_repo.git` |
|`GOOGLE_APPLICATION_CREDENTIALS`      | y |  | path to the service-account key.json |
|`K8S_CLUSTER_NAME`     | y |  | name of k8s cluster |
|`METRIC_NAME`      | y |  | name of Datadog metric |
|`POST_COMMIT_WAIT_MINS`      | n | 10 | if a commit has been made to the git repo within this time, skip the run |
|`TEAM`      | y |  | name of team (used as a tag in Datadog metric) |
|`TF_INIT_ARGS`      | n | "" | args to supply the [terraform init command](https://www.terraform.io/docs/commands/init.html) |
|`TF_PATH`     | y |  |  |
|`TF_PLAN_ARGS`      | n | "" | args to supply the [terraform plan command](https://www.terraform.io/docs/commands/plan.html) |

## notes

* The script won't ever be running `terraform apply`, so the service-account 
used should be locked down to read-only scopes for the resources it needs.

* If using the metric in Datadog Monitors with 'Notify if data is missing' 
enabled, it's recommended to set the 'missing data' threshold value in Datadog
to more than the `POST_COMMIT_WAIT_MINS` value. Otherwise, every time a commit
is made to the git repo, the missing data alert will be fired.

* Contributions are very welcome (please branch or fork and raise PR).