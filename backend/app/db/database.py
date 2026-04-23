import os
from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from dotenv import load_dotenv

# 1. Load the variables from the .env file
load_dotenv()

# 2. Construct the Database URL
# Format: postgresql://user:password@host:port/dbname
DATABASE_URL = f"postgresql://{os.getenv('DB_USER')}:{os.getenv('DB_PASS')}@{os.getenv('DB_HOST')}:{os.getenv('DB_PORT')}/{os.getenv('DB_NAME')}"

# 3. Create the SQLAlchemy Engine
engine = create_engine(DATABASE_URL)

# 4. Create a Session factory (This is how we talk to the DB)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# 5. The Base class that our models will inherit from
Base = declarative_base()

# Helper function to get a database session for your API routes
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()