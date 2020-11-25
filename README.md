# GitHub Action for Bundeling, Micro-batching and Deploying Machine Learning Models to Delphai Cluster 

## Usage

This repository contains GitHub Action for Model serving in production using bentoML and deploying Machine Learning Models to Delphai kubernetes clusters and creates a real-time endpoint/domain on the model to integrate models in other systems.

This Pipeline Steps are the following:

- Authenticate to Azure 
- Clone the entry script
- Clone the model 
- Bundel the Model 
- Run Tests for performance 
- Build docker image 
- Push docker image to delphai container registiry
- Deploy to kubernetes using helm and knative

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

```python
from my_prediction_service import MyPredictionService
svc = MyPredictionService()
svc.pack('my_model', my_sklearn_model)
svc.save()  # default saves to ~/bentoml/repository/MyPredictionService/{version}/
```

Make Sure you provide the model name **Exactly** as it is on Azure Blob.


## Workflow Example

In progress