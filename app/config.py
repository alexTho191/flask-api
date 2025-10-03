import os
from dotenv import load_dotenv

load_dotenv()  # carga variables del .env

class Config:
    SQLALCHEMY_DATABASE_URI = os.getenv("DATABASE_URL", "sqlite:///local.db")
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    DEBUG = True
