import chromadb
import numpy as np
from typing import List, Tuple, Dict, Any
from datetime import datetime, timezone

class ChromaBackend:
    def __init__(self, path: str = "vector_database_server/chroma_data"):
        self.client = chromadb.PersistentClient(path=path)
        self.collection = self.client.get_or_create_collection("memories")

    def add_vector(self, vector: np.ndarray, text: str, metadata: Dict[str, Any]):
        """
        Adds a vector, its corresponding text, and a rich metadata object to the collection.
        """
        doc_id = f"{metadata.get('agent_id', 'unknown')}_{hash(text)}"
        
        self.collection.add(
            embeddings=[vector.tolist()],
            documents=[text],
            metadatas=[metadata],
            ids=[doc_id]
        )

    def search(self, query_vector: np.ndarray, agent_id: str, k: int = 5) -> List[Tuple[float, str]]:
        """
        Searches for k-nearest neighbors for a given agent_id.
        After finding them, it updates their 'last_accessed_time' and 'access_count' metadata.
        """
        results = self.collection.query(
            query_embeddings=[query_vector.tolist()],
            n_results=k,
            where={"agent_id": str(agent_id)}
        )
        
        if not results or not results['ids'][0]:
            return []

        # --- Update metadata for found documents ---
        ids_to_update = results['ids'][0]
        
        # Get current metadata for the found documents
        current_metadatas = self.collection.get(ids=ids_to_update)['metadatas']
        
        updated_metadatas = []
        for meta in current_metadatas:
            new_meta = meta.copy()
            new_meta['access_count'] = new_meta.get('access_count', 0) + 1
            new_meta['last_accessed_time'] = datetime.now(timezone.utc).isoformat()
            updated_metadatas.append(new_meta)

        # Perform the update
        self.collection.update(ids=ids_to_update, metadatas=updated_metadatas)
        # -----------------------------------------

        distances = results['distances'][0]
        documents = results['documents'][0]
        
        return list(zip(distances, documents)) 