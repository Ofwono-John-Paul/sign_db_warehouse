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
from datetime import datetime, timedelta
from sqlalchemy import func

load_dotenv()

app = Flask(__name__)
CORS(app, supports_credentials=True)

app.config['SQLALCHEMY_DATABASE_URI'] = os.getenv("DATABASE_URL", "postgresql://postgres:postgres@localhost:5432/sign_video_db")
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
app.config['JWT_SECRET_KEY'] = "sign-language-warehouse-secret-key-2024"

db = SQLAlchemy(app)
jwt = JWTManager(app)
bcrypt = Bcrypt(app)

UPLOAD_FOLDER = "uploads"
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

# ============================================
# DIMENSION TABLES (Normalized + Star Schema)
# ============================================

class DimRegion(db.Model):
    __tablename__ = "dim_region"
    region_id = db.Column(db.Integer, primary_key=True)
    region_name = db.Column(db.String(100), unique=True, nullable=False)
    
    # Relationships
    districts = db.relationship('DimDistrict', backref='region', lazy=True)


class DimDistrict(db.Model):
    __tablename__ = "dim_district"
    district_id = db.Column(db.Integer, primary_key=True)
    district_name = db.Column(db.String(100), nullable=False)
    region_id = db.Column(db.Integer, db.ForeignKey("dim_region.region_id"), nullable=False)
    
    # Relationships
    schools = db.relationship('DimSchool', backref='district', lazy=True)
    
    __table_args__ = (db.UniqueConstraint('district_name', 'region_id', name='unique_district_region'),)


class DimSchool(db.Model):
    __tablename__ = "dim_school"
    school_id = db.Column(db.Integer, primary_key=True)
    school_name = db.Column(db.String(150), nullable=False)
    district_id = db.Column(db.Integer, db.ForeignKey("dim_district.district_id"), nullable=False)
    email = db.Column(db.String(150), unique=True, nullable=False)
    password_hash = db.Column(db.String(200), nullable=False)
    registered_date = db.Column(db.Date, default=datetime.today().date)
    latitude = db.Column(db.Float, nullable=True)
    longitude = db.Column(db.Float, nullable=True)
    
    # Relationships
    videos = db.relationship('FactSignVideo', backref='school', lazy=True)


class DimSign(db.Model):
    __tablename__ = "dim_sign"
    sign_id = db.Column(db.Integer, primary_key=True)
    sign_name = db.Column(db.String(150), nullable=False)
    medical_category = db.Column(db.String(100), nullable=False)
    description = db.Column(db.Text, nullable=True)
    
    # Relationships
    video_links = db.relationship('FactSignVideo', backref='sign', lazy=True)


class DimVideo(db.Model):
    __tablename__ = "dim_video"
    video_id = db.Column(db.Integer, primary_key=True)
    title = db.Column(db.String(150), nullable=False)
    file_path = db.Column(db.String(500), nullable=False)
    capture_device = db.Column(db.String(100), nullable=True)
    upload_date = db.Column(db.Date, default=datetime.today().date)
    dataset_version = db.Column(db.String(50), default="v1.0")
    
    # Relationships
    fact_links = db.relationship('FactSignVideo', backref='video', lazy=True)
    inference_logs = db.relationship('FactInferenceLog', backref='video', lazy=True)


class DimModelVersion(db.Model):
    __tablename__ = "dim_model_version"
    model_id = db.Column(db.Integer, primary_key=True)
    model_name = db.Column(db.String(100), nullable=False)
    model_version = db.Column(db.String(50), nullable=False)
    training_dataset = db.Column(db.String(100), nullable=True)
    accuracy = db.Column(db.Float, nullable=True)
    precision = db.Column(db.Float, nullable=True)
    recall = db.Column(db.Float, nullable=True)
    f1_score = db.Column(db.Float, nullable=True)
    created_at = db.Column(db.DateTime, default=datetime.now)
    
    # Relationships
    inference_logs = db.relationship('FactInferenceLog', backref='model', lazy=True)


# ============================================
# FACT TABLES
# ============================================

class FactSignVideo(db.Model):
    __tablename__ = "fact_sign_video"
    fact_id = db.Column(db.Integer, primary_key=True)
    school_id = db.Column(db.Integer, db.ForeignKey("dim_school.school_id"), nullable=False)
    sign_id = db.Column(db.Integer, db.ForeignKey("dim_sign.sign_id"), nullable=False)
    video_id = db.Column(db.Integer, db.ForeignKey("dim_video.video_id"), nullable=False)
    upload_timestamp = db.Column(db.DateTime, default=datetime.now)


class FactInferenceLog(db.Model):
    __tablename__ = "fact_inference_log"
    log_id = db.Column(db.Integer, primary_key=True)
    model_id = db.Column(db.Integer, db.ForeignKey("dim_model_version.model_id"), nullable=False)
    video_id = db.Column(db.Integer, db.ForeignKey("dim_video.video_id"), nullable=False)
    predicted_sign = db.Column(db.String(150), nullable=True)
    confidence_score = db.Column(db.Float, nullable=True)
    latency_ms = db.Column(db.Float, nullable=True)
    device_type = db.Column(db.String(50), nullable=True)
    timestamp = db.Column(db.DateTime, default=datetime.now)


# ============================================
# DATABASE INITIALIZATION
# ============================================

with app.app_context():
    db.create_all()
    
    # Seed some initial data if empty
    if DimRegion.query.count() == 0:
        # Uganda Regions
        regions = [
            DimRegion(region_name="Central"),
            DimRegion(region_name="Eastern"),
            DimRegion(region_name="Northern"),
            DimRegion(region_name="Western"),
            DimRegion(region_name="Kampala"),
        ]
        db.session.add_all(regions)
        
        # Some districts
        districts = [
            DimDistrict(district_name="Kampala", region_id=5),
            DimDistrict(district_name="Wakiso", region_id=5),
            DimDistrict(district_name="Mukono", region_id=1),
            DimDistrict(district_name="Jinja", region_id=2),
            DimDistrict(district_name="Gulu", region_id=3),
            DimDistrict(district_name="Mbarara", region_id=4),
            DimDistrict(district_name="Soroti", region_id=2),
            DimDistrict(district_name="Lira", region_id=3),
        ]
        db.session.add_all(districts)
        
        # Some medical sign categories
        signs = [
            DimSign(sign_name="Headache", medical_category="Symptoms", description="Pain in the head region"),
            DimSign(sign_name="Fever", medical_category="Symptoms", description="High body temperature"),
            DimSign(sign_name="Cough", medical_category="Symptoms", description="Expelling air from lungs"),
            DimSign(sign_name="Stomach Pain", medical_category="Symptoms", description="Pain in abdominal region"),
            DimSign(sign_name="Diabetes", medical_category="Diagnosis", description="Blood sugar condition"),
            DimSign(sign_name="Malaria", medical_category="Diagnosis", description="Mosquito-borne disease"),
            DimSign(sign_name="Typhoid", medical_category="Diagnosis", description="Bacterial infection"),
            DimSign(sign_name="HIV", medical_category="Diagnosis", description="Immune system virus"),
            DimSign(sign_name="Yes", medical_category="Basic Expression", description="Affirmative response"),
            DimSign(sign_name="No", medical_category="Basic Expression", description="Negative response"),
            DimSign(sign_name="Please", medical_category="Basic Expression", description="Polite request"),
            DimSign(sign_name="Thank You", medical_category="Basic Expression", description="Expression of gratitude"),
            DimSign(sign_name="Help", medical_category="Emergency", description="Request for assistance"),
            DimSign(sign_name="Doctor", medical_category="Medical Personnel", description="Medical professional"),
            DimSign(sign_name="Hospital", medical_category="Medical Facility", description="Healthcare facility"),
            DimSign(sign_name="Medicine", medical_category="Treatment", description="Medical drugs"),
            DimSign(sign_name="Water", medical_category="Basic Need", description="Drinking water"),
            DimSign(sign_name="Food", medical_category="Basic Need", description="Nutrition"),
            DimSign(sign_name="Pain", medical_category="Symptoms", description="Physical discomfort"),
            DimSign(sign_name="Tired", medical_category="Symptoms", description="Feeling of exhaustion"),
        ]
        db.session.add_all(signs)
        
        # Sample model version
        model = DimModelVersion(
            model_name="SignLanguageCNN",
            model_version="v1.0",
            training_dataset="uganda_sign_v1",
            accuracy=0.85,
            precision=0.82,
            recall=0.83,
            f1_score=0.825
        )
        db.session.add(model)
        
        db.session.commit()
        print("Database seeded with initial data!")


# ============================================
# ROOT ENDPOINT
# ============================================

@app.route("/")
def home():
    return jsonify({
        "message": "Sign Language Data Warehouse API is running",
        "version": "1.0.0",
        "endpoints": {
            "auth": ["/register", "/login"],
            "video": ["/upload"],
            "analytics": [
                "/analytics/videos-per-region",
                "/analytics/videos-per-school",
                "/analytics/sign-distribution",
                "/analytics/dataset-growth",
                "/analytics/model-performance"
            ]
        }
    })


# ============================================
# AUTHENTICATION ENDPOINTS
# ============================================

@app.route('/register', methods=['POST'])
def register():
    data = request.get_json()
    
    school_name = data.get('school_name')
    district_name = data.get('district')
    region_name = data.get('region')
    email = data.get('email')
    password = data.get('password')
    confirm_password = data.get('confirm_password')
    
    # Validation
    if not all([school_name, district_name, region_name, email, password, confirm_password]):
        return jsonify({"error": "All fields are required"}), 400
    
    if password != confirm_password:
        return jsonify({"error": "Passwords do not match"}), 400
    
    # Check if email already exists
    if DimSchool.query.filter_by(email=email).first():
        return jsonify({"error": "Email already registered"}), 400
    
    # Get or create region
    region = DimRegion.query.filter_by(region_name=region_name).first()
    if not region:
        region = DimRegion(region_name=region_name)
        db.session.add(region)
        db.session.commit()
    
    # Get or create district
    district = DimDistrict.query.filter_by(district_name=district_name, region_id=region.region_id).first()
    if not district:
        district = DimDistrict(district_name=district_name, region_id=region.region_id)
        db.session.add(district)
        db.session.commit()
    
    # Hash password
    hashed_password = bcrypt.generate_password_hash(password).decode('utf-8')
    
    # Create school
    school = DimSchool(
        school_name=school_name,
        district_id=district.district_id,
        email=email,
        password_hash=hashed_password
    )
    
    db.session.add(school)
    db.session.commit()
    
    return jsonify({
        "message": "School registered successfully",
        "school_id": school.school_id,
        "school_name": school.school_name
    }), 200


@app.route('/login', methods=['POST'])
def login():
    data = request.get_json()
    
    email = data.get('email')
    password = data.get('password')
    
    if not email or not password:
        return jsonify({"error": "Email and password are required"}), 400
    
    school = DimSchool.query.filter_by(email=email).first()
    
    if not school or not bcrypt.check_password_hash(school.password_hash, password):
        return jsonify({"error": "Invalid credentials"}), 401
    
    access_token = create_access_token(identity=school.school_id)
    
    return jsonify({
        "token": access_token,
        "school_id": school.school_id,
        "school_name": school.school_name,
        "email": school.email
    }), 200


@app.route('/me', methods=['GET'])
@jwt_required()
def get_current_school():
    school_id = get_jwt_identity()
    school = DimSchool.query.get(school_id)
    
    if not school:
        return jsonify({"error": "School not found"}), 404
    
    district = DimDistrict.query.get(school.district_id)
    region = DimRegion.query.get(district.region_id) if district else None
    
    return jsonify({
        "school_id": school.school_id,
        "school_name": school.school_name,
        "email": school.email,
        "district": district.district_name if district else None,
        "region": region.region_name if region else None,
        "registered_date": school.registered_date.isoformat() if school.registered_date else None
    }), 200


# ============================================
# VIDEO UPLOAD ENDPOINT
# ============================================

@app.route('/upload', methods=['POST'])
@jwt_required()
def upload_video():
    school_id = get_jwt_identity()
    
    title = request.form.get('title')
    sign_category = request.form.get('sign_category')
    sign_name = request.form.get('sign_name')
    capture_device = request.form.get('capture_device', 'Unknown')
    file = request.files.get('file')
    
    if not file:
        return jsonify({"error": "No file uploaded"}), 400
    
    if not all([title, sign_category, sign_name]):
        return jsonify({"error": "Title, sign category, and sign name are required"}), 400
    
    # Save video file
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    filename = f"{timestamp}_{file.filename}"
    filepath = os.path.join(UPLOAD_FOLDER, filename)
    file.save(filepath)
    
    # Get or create sign
    sign = DimSign.query.filter_by(sign_name=sign_name, medical_category=sign_category).first()
    if not sign:
        sign = DimSign(sign_name=sign_name, medical_category=sign_category)
        db.session.add(sign)
        db.session.commit()
    
    # Create video record
    video = DimVideo(
        title=title,
        file_path=filepath,
        capture_device=capture_device,
        upload_date=datetime.today().date()
    )
    db.session.add(video)
    db.session.commit()
    
    # Create fact record linking school, sign, and video
    fact = FactSignVideo(
        school_id=school_id,
        sign_id=sign.sign_id,
        video_id=video.video_id,
        upload_timestamp=datetime.now()
    )
    db.session.add(fact)
    db.session.commit()
    
    return jsonify({
        "message": "Video uploaded successfully",
        "video_id": video.video_id,
        "title": video.title
    }), 200


# ============================================
# ANALYTICS ENDPOINTS
# ============================================

@app.route('/analytics/videos-per-region', methods=['GET'])
def videos_per_region():
    """Returns number of videos uploaded per region"""
    results = db.session.query(
        DimRegion.region_name,
        func.count(FactSignVideo.fact_id).label('video_count')
    ).join(
        DimDistrict, DimDistrict.region_id == DimRegion.region_id
    ).join(
        DimSchool, DimSchool.district_id == DimDistrict.district_id
    ).join(
        FactSignVideo, FactSignVideo.school_id == DimSchool.school_id
    ).group_by(
        DimRegion.region_id, DimRegion.region_name
    ).all()
    
    # Also get regions with zero videos
    all_regions = DimRegion.query.all()
    region_counts = {r.region_name: 0 for r in all_regions}
    for r in results:
        region_counts[r.region_name] = r.video_count
    
    return jsonify([
        {"region": region, "count": count}
        for region, count in region_counts.items()
    ]), 200


@app.route('/analytics/videos-per-school', methods=['GET'])
def videos_per_school():
    """Returns schools ranked by video contributions"""
    results = db.session.query(
        DimSchool.school_name,
        DimRegion.region_name,
        DimDistrict.district_name,
        func.count(FactSignVideo.fact_id).label('video_count')
    ).join(
        DimDistrict, DimDistrict.district_id == DimSchool.district_id
    ).join(
        DimRegion, DimRegion.region_id == DimDistrict.region_id
    ).join(
        FactSignVideo, FactSignVideo.school_id == DimSchool.school_id
    ).group_by(
        DimSchool.school_id, DimSchool.school_name, DimRegion.region_name, DimDistrict.district_name
    ).order_by(
        func.count(FactSignVideo.fact_id).desc()
    ).all()
    
    return jsonify([
        {
            "school_name": r.school_name,
            "region": r.region_name,
            "district": r.district_name,
            "video_count": r.video_count
        }
        for r in results
    ]), 200


@app.route('/analytics/sign-distribution', methods=['GET'])
def sign_distribution():
    """Returns class distribution of sign categories"""
    results = db.session.query(
        DimSign.medical_category,
        DimSign.sign_name,
        func.count(FactSignVideo.fact_id).label('video_count')
    ).join(
        FactSignVideo, FactSignVideo.sign_id == DimSign.sign_id
    ).group_by(
        DimSign.sign_id, DimSign.medical_category, DimSign.sign_name
    ).order_by(
        DimSign.medical_category, func.count(FactSignVideo.fact_id).desc()
    ).all()
    
    # Group by category
    categories = {}
    for r in results:
        if r.medical_category not in categories:
            categories[r.medical_category] = []
        categories[r.medical_category].append({
            "sign_name": r.sign_name,
            "count": r.video_count
        })
    
    return jsonify(categories), 200


@app.route('/analytics/dataset-growth', methods=['GET'])
def dataset_growth():
    """Returns videos uploaded over time (daily/weekly/monthly)"""
    # Get date range parameter
    period = request.args.get('period', 'daily')  # daily, weekly, monthly
    
    if period == 'monthly':
        results = db.session.query(
            func.extract('year', FactSignVideo.upload_timestamp).label('year'),
            func.extract('month', FactSignVideo.upload_timestamp).label('month'),
            func.count(FactSignVideo.fact_id).label('count')
        ).group_by(
            func.extract('year', FactSignVideo.upload_timestamp),
            func.extract('month', FactSignVideo.upload_timestamp)
        ).order_by(
            func.extract('year', FactSignVideo.upload_timestamp),
            func.extract('month', FactSignVideo.upload_timestamp)
        ).all()
        
        return jsonify([
            {
                "period": f"{int(r.year)}-{int(r.month):02d}",
                "count": r.count
            }
            for r in results
        ]), 200
    
    elif period == 'weekly':
        results = db.session.query(
            func.date_trunc('week', FactSignVideo.upload_timestamp).label('week'),
            func.count(FactSignVideo.fact_id).label('count')
        ).group_by(
            func.date_trunc('week', FactSignVideo.upload_timestamp)
        ).order_by(
            func.date_trunc('week', FactSignVideo.upload_timestamp)
        ).all()
        
        return jsonify([
            {
                "period": r.week.strftime('%Y-%m-%d') if r.week else None,
                "count": r.count
            }
            for r in results
        ]), 200
    
    else:  # daily
        results = db.session.query(
            func.date(FactSignVideo.upload_timestamp).label('date'),
            func.count(FactSignVideo.fact_id).label('count')
        ).group_by(
            func.date(FactSignVideo.upload_timestamp)
        ).order_by(
            func.date(FactSignVideo.upload_timestamp)
        ).all()
        
        return jsonify([
            {
                "period": r.date.isoformat() if r.date else None,
                "count": r.count
            }
            for r in results
        ]), 200


@app.route('/analytics/model-performance', methods=['GET'])
def model_performance():
    """Returns model performance metrics"""
    models = DimModelVersion.query.order_by(DimModelVersion.created_at.desc()).all()
    
    return jsonify([
        {
            "model_id": m.model_id,
            "model_name": m.model_name,
            "model_version": m.model_version,
            "training_dataset": m.training_dataset,
            "accuracy": m.accuracy,
            "precision": m.precision,
            "recall": m.recall,
            "f1_score": m.f1_score,
            "created_at": m.created_at.isoformat() if m.created_at else None
        }
        for m in models
    ]), 200


@app.route('/analytics/dashboard-summary', methods=['GET'])
def dashboard_summary():
    """Returns summary statistics for dashboard"""
    # Total videos
    total_videos = db.session.query(func.count(FactSignVideo.fact_id)).scalar() or 0
    
    # Total schools
    total_schools = db.session.query(func.count(DimSchool.school_id)).scalar() or 0
    
    # Videos today
    today = datetime.today().date()
    videos_today = db.session.query(func.count(FactSignVideo.fact_id)).filter(
        func.date(FactSignVideo.upload_timestamp) == today
    ).scalar() or 0
    
    # Top contributing school
    top_school = db.session.query(
        DimSchool.school_name,
        func.count(FactSignVideo.fact_id).label('video_count')
    ).join(
        FactSignVideo, FactSignVideo.school_id == DimSchool.school_id
    ).group_by(
        DimSchool.school_id, DimSchool.school_name
    ).order_by(
        func.count(FactSignVideo.fact_id).desc()
    ).first()
    
    # Total signs
    total_signs = db.session.query(func.count(DimSign.sign_id)).scalar() or 0
    
    # Categories
    total_categories = db.session.query(
        func.count(func.distinct(DimSign.medical_category))
    ).scalar() or 0
    
    return jsonify({
        "total_videos": total_videos,
        "total_schools": total_schools,
        "videos_today": videos_today,
        "top_school": {
            "name": top_school.school_name if top_school else "N/A",
            "count": top_school.video_count if top_school else 0
        },
        "total_signs": total_signs,
        "total_categories": total_categories
    }), 200


@app.route('/analytics/school-map', methods=['GET'])
def school_map():
    """Returns school locations for map display"""
    schools = DimSchool.query.all()
    
    result = []
    for school in schools:
        district = DimDistrict.query.get(school.district_id)
        region = DimRegion.query.get(district.region_id) if district else None
        
        # Count videos for this school
        video_count = db.session.query(func.count(FactSignVideo.fact_id)).filter(
            FactSignVideo.school_id == school.school_id
        ).scalar() or 0
        
        result.append({
            "school_id": school.school_id,
            "school_name": school.school_name,
            "district": district.district_name if district else None,
            "region": region.region_name if region else None,
            "latitude": school.latitude,
            "longitude": school.longitude,
            "video_count": video_count
        })
    
    return jsonify(result), 200


# ============================================
# INFERENCE LOG ENDPOINT (Future)
# ============================================

@app.route('/inference/log', methods=['POST'])
@jwt_required()
def log_inference():
    """Log inference results (for future model integration)"""
    data = request.get_json()
    
    model_id = data.get('model_id')
    video_id = data.get('video_id')
    predicted_sign = data.get('predicted_sign')
    confidence_score = data.get('confidence_score')
    latency_ms = data.get('latency_ms')
    device_type = data.get('device_type')
    
    log = FactInferenceLog(
        model_id=model_id,
        video_id=video_id,
        predicted_sign=predicted_sign,
        confidence_score=confidence_score,
        latency_ms=latency_ms,
        device_type=device_type,
        timestamp=datetime.now()
    )
    
    db.session.add(log)
    db.session.commit()
    
    return jsonify({"message": "Inference logged successfully"}), 200


@app.route('/analytics/inference-logs', methods=['GET'])
def get_inference_logs():
    """Get inference logs for real-time monitoring"""
    limit = request.args.get('limit', 50, type=int)
    
    logs = FactInferenceLog.query.order_by(
        FactInferenceLog.timestamp.desc()
    ).limit(limit).all()
    
    return jsonify([
        {
            "log_id": log.log_id,
            "model_name": log.model.model_name if log.model else None,
            "video_id": log.video_id,
            "predicted_sign": log.predicted_sign,
            "confidence_score": log.confidence_score,
            "latency_ms": log.latency_ms,
            "device_type": log.device_type,
            "timestamp": log.timestamp.isoformat() if log.timestamp else None
        }
        for log in logs
    ]), 200


# ============================================
# MAIN ENTRY POINT
# ============================================

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)
