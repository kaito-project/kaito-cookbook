import json
import os

import requests
from llama_index.core import Document, SimpleDirectoryReader


def read_pdfs_from_directory(directory_path: str) -> list[Document]:
    """
    Read all PDF files from the specified directory using SimpleDirectoryReader.

    Args:
        directory_path (str): Path to the directory containing PDF files

    Returns:
        list[Document]: List of loaded document objects
    """
    if not os.path.exists(directory_path):
        raise ValueError(f"Directory {directory_path} does not exist")

    print(f"Reading PDF files from: {directory_path}")

    # Create SimpleDirectoryReader instance with PDF filter
    reader = SimpleDirectoryReader(
        input_dir=directory_path,
        required_exts=[".pdf"],  # Only process PDF files
    )

    # Load documents
    documents = reader.load_data()
    print(f"Loaded {len(documents)} PDF documents")

    return documents


def extract_text_from_documents(documents: list[Document]) -> list[dict]:
    """
    Extract text content from Document objects.

    Args:
        documents (list[Document]): List of Document objects

    Returns:
        list[dict]: List of dictionaries containing document metadata and text
    """
    extracted_docs = []

    for i, doc in enumerate(documents):
        # Extract text content
        text_content = doc.text if hasattr(doc, "text") else str(doc)

        # Extract metadata
        full_metadata = doc.metadata if hasattr(doc, "metadata") else {}

        # Get filename from metadata or use index
        filename = full_metadata.get("file_name", f"document_{i}.pdf")

        # Extract ticker from filename (remove .pdf extension)
        ticker = os.path.splitext(os.path.basename(filename))[0]

        # Use filename as ticker in metadata
        metadata = {"ticker": ticker}

        doc_data = {"text": text_content, "metadata": metadata}

        extracted_docs.append(doc_data)
        print(f"Extracted text from: {filename} ({len(text_content)} characters)")

    return extracted_docs


def index_documents_to_server(
    documents: list[dict],
    index_name: str = "10-k",
    server_url: str = "http://localhost:8080/index",
    batch_size: int = 50,
) -> bool:
    """
    Send documents to the server for indexing via POST request in batches.

    Args:
        documents (list[dict]): List of document dictionaries
        index_name (str): Name of the index to create
        server_url (str): URL of the indexing endpoint
        batch_size (int): Number of documents per request

    Returns:
        bool: True if all batches are successful, False otherwise
    """
    if not documents:
        print("No documents to index.")
        return True

    total = len(documents)
    num_batches = (total + batch_size - 1) // batch_size

    headers = {"Content-Type": "application/json", "Accept": "application/json"}
    print(f"Sending {total} documents to {server_url} in {num_batches} batch(es) of up to {batch_size} each")
    print(f"Index name: {index_name}")

    all_ok = True
    for i in range(0, total, batch_size):
        batch_num = (i // batch_size) + 1
        batch_docs = documents[i : i + batch_size]

        payload = {"index_name": index_name, "documents": batch_docs}
        print(f"\nBatch {batch_num}/{num_batches}: indexing {len(batch_docs)} document(s)...")

        try:
            response = requests.post(
                server_url,
                data=json.dumps(payload),
                headers=headers,
                timeout=300,  # 5 minute timeout for large documents
            )

            if response.status_code == 200:
                print(f"Batch {batch_num} indexed successfully.")
                try:
                    response_data = response.json()
                    # Keep verbose server output minimal but available
                    if isinstance(response_data, dict):
                        message = response_data.get("message")
                        if message:
                            print(f"Server message: {message}")
                    else:
                        print(f"Server response: {response_data}")
                except json.JSONDecodeError:
                    # Not JSON; print raw text
                    if response.text:
                        print(f"Server response: {response.text}")
            else:
                all_ok = False
                print(
                    f"Batch {batch_num} failed. Status code: {response.status_code}\nResponse: {response.text}"
                )
        except requests.exceptions.RequestException as e:
            all_ok = False
            print(f"Batch {batch_num} request failed: {e}")
        except Exception as e:
            all_ok = False
            print(f"Batch {batch_num} unexpected error: {e}")

    if all_ok:
        print("\nSuccessfully indexed all batches!")
    else:
        print("\nCompleted with errors. Some batches failed to index.")

    return all_ok


def main():
    """
    Main function to orchestrate the PDF reading and indexing process.
    """
    # Configuration
    pdf_directory = "10-K"
    index_name = "10-k"
    server_url = "http://localhost:8000/index"

    try:
        # Step 1: Read PDF files from directory
        print("=" * 50)
        print("Step 1: Reading PDF files from directory")
        print("=" * 50)
        documents = read_pdfs_from_directory(pdf_directory)

        if not documents:
            print("No PDF documents found in the directory.")
            return

        # Step 2: Extract text from documents
        print("\n" + "=" * 50)
        print("Step 2: Extracting text from documents")
        print("=" * 50)
        extracted_docs = extract_text_from_documents(documents)

        # Step 3: Index documents to server
        print("\n" + "=" * 50)
        print("Step 3: Indexing documents to server")
        print("=" * 50)
        success = index_documents_to_server(extracted_docs, index_name, server_url)

        if success:
            print("\n🎉 Successfully completed indexing process!")
        else:
            print("\n❌ Failed to complete indexing process.")

    except Exception as e:
        print(f"Error in main process: {e}")
        return 1

    return 0


if __name__ == "__main__":
    exit(main())
