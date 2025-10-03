from flask import Blueprint, jsonify
from app.models import Usuario
from app import db

main = Blueprint('main', __name__)

# Ruta raíz
@main.route('/')
def home():
    return jsonify({"mensaje": "API Flask funcionando 🚀"})

# Ruta para traer todos los usuarios
@main.route('/usuarios', methods=['GET'])
def get_usuarios():
    try:
        usuarios = Usuario.query.all()
        return jsonify([usuario.traer_usuario() for usuario in usuarios])
    except Exception as e:
        return jsonify({"error": str(e)}), 500