from flask import Flask, request, jsonify
from flask_sqlalchemy import SQLAlchemy
from flask_cors import CORS
from flask_jwt_extended import (
    JWTManager,
    create_access_token,
    jwt_required,
    get_jwt_identity
)
from flask_bcrypt import Bcrypt
import os
from dotenv import load_dotenv
from datetime import datetime

app = Flask(__name__)
CORS(app, supports_credentials=True)

load_dotenv()

app.config['SQLALCHEMY_DATABASE_URI'] = os.getenv("DATABASE_URL")
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
app.config['JWT_SECRET_KEY'] = "super-secret-key-change-this"

db = SQLAlchemy(app)
jwt = JWTManager(app)
bcrypt = Bcrypt(app)

UPLOAD_FOLDER = "uploads"
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

# DATABASE MODELS
class DimRegion(db.Model):
    __tablename__ = "dim_region"
    region_id = db.Column(db.Integer, primary_key=True)
    region_name = db.Column(db.String(100), unique=True)


class DimSchool(db.Model):
    __tablename__ = "dim_school"
    school_id = db.Column(db.Integer, primary_key=True)
    school_name = db.Column(db.String(150))
    district = db.Column(db.String(100))
    region_id = db.Column(db.Integer, db.ForeignKey("dim_region.region_id"))
    email = db.Column(db.String(150), unique=True)
    password_hash = db.Column(db.String(200))


class DimVideo(db.Model):
    __tablename__ = "dim_video"
    video_id = db.Column(db.Integer, primary_key=True)
    title = db.Column(db.String(150))
    category = db.Column(db.String(100))
    file_path = db.Column(db.String(200))
    upload_date = db.Column(db.Date)


class FactSignVideo(db.Model):
    __tablename__ = "fact_sign_video"
    fact_id = db.Column(db.Integer, primary_key=True)
    school_id = db.Column(db.Integer, db.ForeignKey("dim_school.school_id"))
    video_id = db.Column(db.Integer, db.ForeignKey("dim_video.video_id"))
    upload_timestamp = db.Column(db.DateTime)


with app.app_context():
    db.create_all()

@app.route("/")
def home():
    return jsonify({
        "message": "Sign Language Data Warehouse API is running"
    })

# REGISTER SCHOOL
@app.route('/register', methods=['POST'])
def register():
    data = request.get_json()

    school_name = data['school_name']
    district = data['district']
    region_name = data['region']
    email = data['email']
    password = data['password']

    # Check if region exists
    region = DimRegion.query.filter_by(region_name=region_name).first()
    if not region:
        region = DimRegion(region_name=region_name)
        db.session.add(region)
        db.session.commit()

    # Hash password
    hashed_password = bcrypt.generate_password_hash(password).decode('utf-8')

    school = DimSchool(
        school_name=school_name,
        district=district,
        region_id=region.region_id,
        email=email,
        password_hash=hashed_password
    )

    db.session.add(school)
    db.session.commit()

    return jsonify({"message": "School registered successfully"}), 200


# LOGIN
@app.route('/login', methods=['POST'])
def login():
    data = request.get_json()

    email = data['email']
    password = data['password']

    school = DimSchool.query.filter_by(email=email).first()

    if not school or not bcrypt.check_password_hash(school.password_hash, password):
        return jsonify({"message": "Invalid credentials"}), 401

    access_token = create_access_token(identity=school.school_id)

    return jsonify({
        "token": access_token,
        "school_name": school.school_name
    }), 200

# PROTECTED UPLOAD
@app.route('/upload', methods=['POST'])
@jwt_required()
def upload():

    school_id = get_jwt_identity()

    title = request.form['title']
    category = request.form['category']
    file = request.files['file']

    if not file:
        return jsonify({"error": "No file uploaded"}), 400

    filepath = os.path.join(UPLOAD_FOLDER, file.filename)
    file.save(filepath)

    video = DimVideo(
        title=title,
        category=category,
        file_path=filepath,
        upload_date=datetime.today().date()
    )
    db.session.add(video)
    db.session.commit()

    fact = FactSignVideo(
        school_id=school_id,
        video_id=video.video_id,
        upload_timestamp=datetime.now()
    )
    db.session.add(fact)
    db.session.commit()

    return jsonify({"message": "Video uploaded successfully"}), 200


if __name__ == '__main__':
    app.run(debug=True)