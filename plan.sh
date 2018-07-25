: “${DD_API_KEY?'DD_API_KEY is required'}”
: “${ENV?'ENV is required'}”
: “${GCP_PROJECT_NAME?'GCP_PROJECT_NAME is required'}”
: “${GCP_ZONE?'GCP_ZONE is required'}”
: “${GIT_CLONE_STRING?'ENV is required'}”
: “${GOOGLE_APPLICATION_CREDENTIALS?'GOOGLE_APPLICATION_CREDENTIALS is required'}”
: “${K8S_CLUSTER_NAME?'K8S_CLUSTER_NAME is required'}”
: “${METRIC_NAME?'METRIC_NAME is required'}”
: “${TEAM?'TEAM is required'}”
: “${TF_PATH?'TF_PATH is required'}”

echo "authing..."
gcloud auth activate-service-account --key-file=key.json || exit 1
shred key.json -u
gcloud container clusters get-credentials $K8S_CLUSTER_NAME --project=$GCP_PROJECT_NAME --zone=$GCP_ZONE || exit 1

cd /home/tf
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

if [ $mins_since_last_commit -gt $POST_COMMIT_WAIT_MINS ]; then
  echo "terraforming..."
  terraform init $TF_INIT_ARGS &>/dev/null
  terraform plan $TF_PLAN_ARGS -no-color > tf_plan.json -detailed-exitcode; echo $? > status.txt
  status="$(cat status.txt)"
  currenttime=$(date +%s)

  echo "posting metric to datadog..."
  curl  -X POST -H "Content-type: application/json" \
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