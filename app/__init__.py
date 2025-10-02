from flask import Flask
from flask_sqlalchemy import SQLAlchemy

db = SQLAlchemy()

def create_app():
    app = Flask(__name__)

    # Configuración de la base de datos
    app.config.from_object('app.config.Config')

    # Inicializar la DB
    db.init_app(app)

    # Registrar rutas
    from app.routes import main
    app.register_blueprint(main)

    return app
