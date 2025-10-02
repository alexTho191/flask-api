from flask import Blueprint, jsonify
from app.models import Usuario
from app import db

main = Blueprint('main', __name__)

@main.route('/')
def home():
    return jsonify({"mensaje": "API Flask funcionando 🚀"})

@main.route('/usuarios', methods=['GET'])
def get_usuarios():
    try:
        usuarios = Usuario.query.all()
        return jsonify([usuario.to_dict() for usuario in usuarios])
    except Exception as e:
        return jsonify({"error": str(e)}), 500
