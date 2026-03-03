from flask import Flask, request, jsonify
from flask_sqlalchemy import SQLAlchemy
from flask_cors import CORS
import os
from dotenv import load_dotenv
from datetime import datetime

load_dotenv()

app = Flask(__name__)
CORS(app)

# DATABASE CONFIGURATION
app.config['SQLALCHEMY_DATABASE_URI'] = os.getenv("DATABASE_URL")
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

db = SQLAlchemy(app)

# UPLOAD FOLDER
UPLOAD_FOLDER = "uploads"
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

# DIMENSION TABLES
class DimRegion(db.Model):
    __tablename__ = "dim_region"

    region_id = db.Column(db.Integer, primary_key=True)
    region_name = db.Column(db.String(100), unique=True, nullable=False)

    schools = db.relationship("DimSchool", backref="region", lazy=True)


class DimSchool(db.Model):
    __tablename__ = "dim_school"

    school_id = db.Column(db.Integer, primary_key=True)
    school_name = db.Column(db.String(150), nullable=False)
    district = db.Column(db.String(100))
    latitude = db.Column(db.Float)
    longitude = db.Column(db.Float)

    region_id = db.Column(db.Integer, db.ForeignKey("dim_region.region_id"), nullable=False)


class DimVideo(db.Model):
    __tablename__ = "dim_video"

    video_id = db.Column(db.Integer, primary_key=True)
    title = db.Column(db.String(150))
    category = db.Column(db.String(100))
    file_path = db.Column(db.String(200))
    upload_date = db.Column(db.Date)

# FACT TABLE
class FactSignVideo(db.Model):
    __tablename__ = "fact_sign_video"

    fact_id = db.Column(db.Integer, primary_key=True)
    school_id = db.Column(db.Integer, db.ForeignKey("dim_school.school_id"), nullable=False)
    video_id = db.Column(db.Integer, db.ForeignKey("dim_video.video_id"), nullable=False)
    upload_timestamp = db.Column(db.DateTime)

# CREATE TABLES
with app.app_context():
    db.create_all()

# API ROUTES
# Get all schools (Flutter will use this for dropdown)
@app.route("/schools", methods=["GET"])
def get_schools():
    schools = DimSchool.query.all()
    result = []

    for school in schools:
        result.append({
            "school_id": school.school_id,
            "school_name": school.school_name,
            "district": school.district,
            "region": school.region.region_name
        })

    return jsonify(result)


# Upload endpoint
@app.route("/upload", methods=["POST"])
def upload():

    title = request.form.get("title")
    category = request.form.get("category")
    school_id = request.form.get("school_id")
    file = request.files.get("file")

    if not all([title, category, school_id, file]):
        return jsonify({"error": "Missing required fields"}), 400

    # Validate school exists
    school = DimSchool.query.get(school_id)
    if not school:
        return jsonify({"error": "Invalid school selected"}), 400

    # Save file
    filepath = os.path.join(UPLOAD_FOLDER, file.filename)
    file.save(filepath)

    # Insert into DimVideo
    video = DimVideo(
        title=title,
        category=category,
        file_path=filepath,
        upload_date=datetime.today().date()
    )
    db.session.add(video)
    db.session.commit()

    # Insert into FactSignVideo
    fact = FactSignVideo(
        school_id=school.school_id,
        video_id=video.video_id,
        upload_timestamp=datetime.now()
    )
    db.session.add(fact)
    db.session.commit()

    return jsonify({"message": "Video uploaded successfully"})


# RUN APP
if __name__ == "__main__":
    app.run(debug=True)