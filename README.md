# food-delivery-analytics-ai
# FD Analytics & AI Capstone

End-to-end data pipeline, BigQuery warehouse (`fd_raw`, `fd_staging`, `fd_marts`, `fd_ai`), and Vertex AI (Gemini) analytics platform built on Google Cloud (`asia-south1`).

## Repository Structure
- `src/` — Application and data ingestion pipeline code
- `sql/` — BigQuery DDL, transformations, and `fd_ai` model queries
- `notebooks/` — Exploratory analysis and Vertex AI prototyping
- `docs/` — Architecture diagrams and capstone documentation

## Team Guidelines
- Never commit `.env` files, service account JSON keys, or raw datasets.
- All changes to `main` must go through a feature branch and Pull Request.
