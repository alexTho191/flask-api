from app import db

class Usuario(db.Model):
    __tablename__ = 'usuarios'
    id = db.Column(db.Integer, primary_key=True)
    nombre = db.Column(db.String(50), nullable=False)
    email = db.Column(db.String(100), unique=True, nullable=False)
    creado_en = db.Column(db.DateTime, default=db.func.current_timestamp())

    def traer_usuario(self):
        return {
            'id': self.id,
            'nombre': self.nombre,
            'email': self.email,
            'creado_en': self.creado_en.strftime("%Y-%m-%d %H:%M:%S") if self.creado_en else None
        }
    
    def login(self):
        return {
            'id': self.id,
            'nombre': self.nombre
        }
    
    def __repr__(self):
        return f'<Usuario {self.nombre}>'
