import os
from flask import Flask, jsonify
from prometheus_flask_exporter import PrometheusMetrics
from dotenv import load_dotenv

load_dotenv()


def create_app():
    app = Flask(__name__)
    
    # Configure app
    app.config["APP_VERSION"] = os.environ.get("APP_VERSION", "1.0.0")
    app.config["SECRET_KEY"] = os.environ.get("SECRET_KEY", "dev-secret-key")
    
    # Initialize Prometheus metrics
    PrometheusMetrics(app)
    
    # Register blueprints
    from app.routes import main
    app.register_blueprint(main)
    
    # Custom error handlers
    @app.errorhandler(404)
    def not_found(e):
        return jsonify({"error": "not found", "status": 404}), 404
    
    @app.errorhandler(500)
    def internal_error(e):
        return jsonify({"error": "internal error", "status": 500}), 500
    
    return app
