config_file="./tf_planner.conf"
if [ ! -z $CONFIG_PATH ] ; then
  config_file=$CONFIG_PATH
fi

if [ -f $config_file ] ; then
IFS="="
while read -r name value
do
export "$name"="$value"
done < $config_file
fi

[ -z "$DD_API_KEY" ] && echo "DD_API_KEY is required" && invalid=true
[ -z "$DD_ENV" ] && echo "DD_ENV is required" && invalid=true
[ -z "$DD_METRIC_NAME" ] && echo "DD_METRIC_NAME is required" && invalid=true
[ -z "$DD_TEAM" ] && echo "DD_TEAM is required" && invalid=true
[ -z "$GIT_CLONE_STRING" ] && echo "GIT_CLONE_STRING is required" && invalid=true
[ -z "$GOOGLE_APPLICATION_CREDENTIALS" ] && echo "GOOGLE_APPLICATION_CREDENTIALS is required" && invalid=true
[ -z "$TF_PATH" ] && echo "TF_PATH is required" && invalid=true

if [ "$invalid" = true ] ; then
    exit 1
fi

echo "verifying Datadog API Key..."
api_check_status=$(curl -s -o /dev/null -w "%{http_code}" \
  "https://api.datadoghq.com/api/v1/validate?api_key=$DD_API_KEY")

if [[ $api_check_status != 200 ]]; then
  echo $api_check_status
  echo "Datadog API key is invalid, check https://app.datadoghq.com/account/settings#api"
  exit 1
fi

if [[ ! -z $K8S_CLUSTER_NAME ]]; then
  echo "authing google..."
  gcloud auth activate-service-account \
    --key-file=$GOOGLE_APPLICATION_CREDENTIALS || exit 1
  echo "authing gke..."
  gcloud container clusters get-credentials $K8S_CLUSTER_NAME \
    --project=$GCP_PROJECT_NAME \
    --zone=$GCP_ZONE \
  || exit 1
fi

cd /home/tf
echo "verifying github public key fingerprint..."
GH_FINGERPRINT=SHA256:$(ssh-keyscan github.com 2> /dev/null > githubKey \
  && ssh-keygen -lf githubKey | sed -e 's/.*SHA256:\(.*\)github.com.*/\1/') \
  && curl https://help.github.com/articles/github-s-ssh-key-fingerprints/ -s \
  | grep -q $(echo $GH_FINGERPRINT)
cat githubKey >> /home/tf/.ssh/known_hosts

echo "cloning $GIT_CLONE_STRING..."
git clone --quiet --depth 1 $GIT_CLONE_STRING || exit 1
cd $TF_PATH
now=$(date +%s)
last_commit=$(git log --pretty=format:'%at' -1)
secs_since_last_commit=$((now-last_commit))
mins_since_last_commit=$((secs_since_last_commit/60))

if [[ -z $POST_COMMIT_WAIT_MINS ]]; then
  wait_mins=10
else
  wait_mins=$POST_COMMIT_WAIT_MINS
fi

if [ $mins_since_last_commit -gt $wait_mins ]; then
  echo "terraforming..."
  terraform init $TF_INIT_ARGS &>/dev/null
  terraform plan $TF_PLAN_ARGS -no-color > tf_plan.json -detailed-exitcode; \
    echo $? > status.txt
  status="$(cat status.txt)"
  currenttime=$(date +%s)

  echo "posting metric to datadog..."
  curl -s -X POST -H "Content-type: application/json" \
  -d "{ \"series\" :
           [{\"metric\":\"$METRIC_NAME\",
            \"points\":[[$currenttime, $status]],
            \"type\":\"count\",
            \"tags\":[\"team:$TEAM\",\"environment:$ENV\"]}
          ]
  }" \
  "https://api.datadoghq.com/api/v1/series?api_key=$DD_API_KEY"
else
  echo "Didn't do anything as it's only $mins_since_last_commit mins since last git commit..."
fi
