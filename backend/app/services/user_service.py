from app.models.profile import Profile
from passlib.context import CryptContext
from sqlalchemy.orm import Session

class UserService:
    pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

    def __init__(self, db: Session):
        self.db = db

    def create_user(self, full_name: str, password: str, email: str = None, phone_number: str = None) -> Profile:
        hashed_password = self.hash_password(password)
        new_user = Profile(full_name=full_name, hash_password=hashed_password, email=email, phone_number=phone_number)

        if self.db.query(Profile).filter(Profile.full_name == full_name).first():
            raise ValueError("User with this full name already exists.")
        
        if(len(password) < 6):
            raise ValueError("Password must be at least 6 characters long.")
        
        self.db.add(new_user)
        self.db.commit()
        self.db.refresh(new_user)
        return new_user

    def hash_password(self, password: str) -> str:
        return self.pwd_context.hash(password)

    def verify_password(self, plain_password: str, hashed_password: str) -> bool:
        return self.pwd_context.verify(plain_password, hashed_password)

    def authenticate_user(self, full_name: str, password: str) -> Profile:
        # Search the Profile table in the DB
        user = self.db.query(Profile).filter(Profile.full_name == full_name).first()
        
        if user and self.verify_password(password, user.hash_password):
            return user
        return None