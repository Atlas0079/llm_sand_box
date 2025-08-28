from fastapi import FastAPI, HTTPException, Depends
from pydantic import BaseModel, Field
from typing import List, Optional
import numpy as np
import requests
import os

from faiss_backend import FaissBackend

app = FastAPI()

# Configuration
# It's better to load these from environment variables or a config file in a real application.
THIRD_PARTY_API_URL = os.getenv("THIRD_PARTY_API_URL", "https://api.example.com/embed") # Placeholder URL
DEFAULT_MODEL = "text-embedding-ada-002"

# Initialize backend
backend = FaissBackend(index_path="vector_database_server/data/faiss.index", data_path="vector_database_server/data/data.txt")

class AddRequest(BaseModel):
    text: str
    importance: float = Field(0.5, ge=0.0, le=1.0, description="The importance of the memory (0.0 to 1.0).")
    created_time: str = Field(..., description="The in-game timestamp when the memory was created.")
    memory_type: str = Field("normal", description="The type of the memory ('normal' or 'reflection').")
    api_url: Optional[str] = None
    api_token: Optional[str] = None
    model: Optional[str] = DEFAULT_MODEL

class SearchRequest(BaseModel):
    text: str
    k: int = 5
    api_url: Optional[str] = None
    api_token: Optional[str] = None
    model: Optional[str] = DEFAULT_MODEL

def get_embedding_from_api(text: str, api_url: str, api_token: str, model: str) -> np.ndarray:
    """Helper function to get embeddings from a third-party API."""
    headers = {
        "Authorization": f"Bearer {api_token}",
        "Content-Type": "application/json"
    }
    data = {
        "input": text,
        "model": model
    }
    
    try:
        response = requests.post(api_url, headers=headers, json=data)
        response.raise_for_status() # Raises an exception for 4XX/5XX errors
        
        embedding = response.json().get("data", [{}])[0].get("embedding")
        if not embedding:
            raise HTTPException(status_code=500, detail="Failed to get embedding from API response.")
            
        return np.array([embedding])
    except requests.exceptions.RequestException as e:
        raise HTTPException(status_code=500, detail=f"API request failed: {e}")

@app.post("/add")
def add_document(request: AddRequest):
    """
    Receives text, calls a third-party API to get the embedding, 
    and adds the vector to the Faiss index.
    """
    url = request.api_url or THIRD_PARTY_API_URL
    token = request.api_token

    if not token:
        raise HTTPException(status_code=400, detail="API token is required.")

    try:
        embedding = get_embedding_from_api(request.text, url, token, request.model)
        
        # Assemble the rich metadata object using client-provided time
        metadata = {
            "agent_id": request.agent_id,
            "created_time": request.created_time,
            "last_accessed_time": request.created_time, # Initially, last access is creation time
            "access_count": 1,
            "importance": request.importance,
            "memory_type": request.memory_type
        }
        
        backend.add_vector(embedding, request.text, metadata)
        return {"message": f"Memory added successfully for agent {request.agent_id}."}
    except HTTPException as e:
        raise e
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/search")
def search_documents(request: SearchRequest):
    """

    Receives a query text, gets its embedding, and searches for similar documents.
    """
    url = request.api_url or THIRD_PARTY_API_URL
    token = request.api_token
    
    if not token:
        raise HTTPException(status_code=400, detail="API token is required for embedding the query.")

    try:
        query_embedding = get_embedding_from_api(request.text, url, token, request.model)
        results = backend.search(query_embedding, k=request.k)
        return {"results": results}
    except HTTPException as e:
        raise e
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/")
def read_root():
    return {"message": "Vector Database Server is running."}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=18191) 