# GitHub Action for Bundeling, Micro-batching and Deploying Machine Learning Models to Delphai Cluster 
[<img src="https://www.cengn.ca/wp-content/uploads/2017/11/docker.png" width="800px" margin-left="10px">](https://github.com/delphai/machine-learning-deployment)

## Usage

This repository contains GitHub Action for Model serving in production using bentoML and deploying Machine Learning Models to Delphai kubernetes clusters and creates a real-time endpoint/domain on the model to integrate models in other systems.


## This pipeline steps are the following:

- Authenticate to Azure 
- Clone the entry script
- Clone the model 
- Bundel the Model 
- Run Tests for performance 
- Build docker image 
- Push docker image to delphai container registiry
- Deploy to kubernetes using helm and knative

## Requirments

- pipenv

**Please note the following:**

Make sure to create a Pipfile and add the required `dependencies` for your model entry script

Make sure that python version is `3.8`

Make sure to run `pipenv install` before pushing to the repo so the `Pipfile.lock` is ready.

```
[[source]]
name = "pypi"
url = "https://pypi.org/simple"
verify_ssl = true

[dev-packages]
yapf = "*"
flake8 = "*"
pep8-naming = "*"
pytest = "*"
mypy = "*"
ipython = "*"
mongomock = "*"
grpc-stubs = "*"
pylint = "*"

[packages]

bentoml = "*"
transformers = "*"
torch = "*"
keras = "*"
tensorflow = "*"

[requires]
python_version = "3.8"
```

- save.py

Please make sure to name the bundling file `save.py` 

Example for `save.py`

```python
from main import TransformerService
from pathlib import Path
from transformers import BertTokenizer, BertForSequenceClassification

ts = TransformerService()
source = Path(__file__).parent.parent

model_dir = f'{source}/<MODEL NAME EXACTLY AS IN AZURE BLOB>'
model = BertForSequenceClassification.from_pretrained(model_dir)
tokenizer = BertTokenizer.from_pretrained(model_dir)

artifact = {"model": model, "tokenizer": tokenizer}
ts.pack("model",artifact)
saved_path = ts.save()
```


## Example for bentoML script

BentoML provides abstractions for creating a prediction service that's bundled with 
trained models. User can define inference APIs with serving logic with Python code and 
specify the expected input/output data type:

```python
import pandas as pd

from bentoml import env, artifacts, api, BentoService
from bentoml.adapters import DataframeInput
from bentoml.frameworks.sklearn import SklearnModelArtifact

from my_library import preprocess

@env(infer_pip_packages=True)
@artifacts([SklearnModelArtifact('my_model')])
class MyPredictionService(BentoService):
    """
    A simple prediction service exposing a Scikit-learn model
    """

    @api(input=DataframeInput(orient="records"), batch=True)
    def predict(self, df: pd.DataFrame):
        """
        An inference API named `predict` with Dataframe input adapter, which defines
        how HTTP requests or CSV files get converted to a pandas Dataframe object as the
        inference API function input
        """
        model_input = preprocess(df)
        return self.artifacts.my_model.predict(model_input)
```

At the end of your model training pipeline, import your BentoML prediction service
class, pack it with your trained model, and persist the entire prediction service with
`save` call at the end:



Make Sure you provide the model name **Exactly** as it is on Azure Blob.


## Workflow Example

```yaml

name: ML Deployment

on:
  push:
    branches:
      - "master"
jobs:
  Deploy_ML:
    runs-on: ubuntu-latest
    steps:
    - name: checkout repo
      uses: actions/checkout@v2
    - run: echo "REPOSITORY_NAME=$(echo "$GITHUB_REPOSITORY" | awk -F / '{print $2}' | sed -e "s/:refs//")" >> $GITHUB_ENV
      shell: bash
    - run: echo "This Repo name is $REPOSITORY_NAME"
    - name: Deploy ML 
      uses: delphai/machine-learning-deployment@master
      with:
        repo_name: bentoml-test
        blob_model: page-classifier-binary
        class_name: 
        client_id: ${{ secrets.ARM_CLIENT_ID_COMMON }}
        client_secret: ${{ secrets.ARM_CLIENT_SECRET_COMMON }}
        tenant_id: ${{ secrets.ARM_TENANT_ID_COMMON }}
        github_token: ${{ secrets.DEVOPS_TOKEN }}
        connection_string: ${{ secrets.BLOB_COMMON_CS }}

```
