from flask import Flask
from flask_sqlalchemy import SQLAlchemy
from flask_cors import CORS

db = SQLAlchemy()

def create_app():
    app = Flask(__name__)
    
    # Configuración de la base de datos
    app.config.from_object('app.config.Config')
    
    # Inicializar la DB
    db.init_app(app)
    
    app.config['JSON_AS_ASCII'] = False
    
    # ✅ Configuración CORS mejorada
    CORS(app, 
         resources={r"/*": {
             "origins": "*",
             "methods": ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
             "allow_headers": ["Content-Type", "Authorization"],
             "expose_headers": ["Content-Type"],
             "supports_credentials": False
         }})
    
    # Registrar rutas
    from app.routes import main
    app.register_blueprint(main)
    
    return app