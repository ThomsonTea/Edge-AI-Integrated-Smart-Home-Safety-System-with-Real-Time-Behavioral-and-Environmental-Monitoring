import unittest

from fastapi import HTTPException
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.api.dev.api import api_router
from app.api.dev.endpoints.emergency_contacts import (
    create_emergency_contact,
    delete_emergency_contact,
    list_emergency_contacts,
    update_emergency_contact,
)
from app.db.database import Base
from app.models import EmergencyContact, Premise, Profile
from app.schemas.emergency_contact import (
    EmergencyContactCreate,
    EmergencyContactResponse,
    EmergencyContactUpdate,
)


class EmergencyContactTests(unittest.TestCase):
    def setUp(self):
        self.engine = create_engine(
            "sqlite://",
            connect_args={"check_same_thread": False},
            poolclass=StaticPool,
        )
        Base.metadata.create_all(self.engine)
        self.Session = sessionmaker(bind=self.engine)
        self.db = self.Session()
        self.db.add_all(
            [
                Premise(id=1, name="Home"),
                Premise(id=2, name="Other home"),
                Profile(
                    id=1,
                    premise_id=1,
                    username="owner",
                    email="owner@example.com",
                    group_type="owner",
                    hash_password="hash",
                ),
                Profile(
                    id=2,
                    premise_id=1,
                    username="resident",
                    email="resident@example.com",
                    group_type="normal_user",
                    hash_password="hash",
                ),
                Profile(
                    id=3,
                    premise_id=2,
                    username="other-owner",
                    email="other@example.com",
                    group_type="owner",
                    hash_password="hash",
                ),
            ]
        )
        self.db.commit()

    def tearDown(self):
        self.db.close()
        Base.metadata.drop_all(self.engine)
        self.engine.dispose()

    def test_routes_are_registered(self):
        paths = {getattr(route, "path", None) for route in api_router.routes}
        self.assertIn("/emergency-contacts", paths)
        self.assertIn("/emergency-contacts/{contact_id}", paths)

    def test_owner_can_create_and_normal_user_can_list_own_premise(self):
        contact = create_emergency_contact(
            EmergencyContactCreate(
                contact_name="  Nearby neighbour  ",
                phone_number="+60 12-345 6789",
                relationship=" Neighbour ",
                priority=2,
            ),
            current_user={"user_id": 1},
            db=self.db,
        )

        listed = list_emergency_contacts(
            current_user={"user_id": 2},
            db=self.db,
        )

        self.assertEqual(len(listed), 1)
        self.assertEqual(listed[0].id, contact.id)
        self.assertEqual(contact.contact_name, "Nearby neighbour")
        self.assertEqual(contact.phone_number, "+60123456789")
        response = EmergencyContactResponse.model_validate(contact)
        self.assertEqual(response.relationship, "Neighbour")

    def test_contacts_are_isolated_by_premise(self):
        self.db.add_all(
            [
                EmergencyContact(
                    id=1,
                    premise_id=1,
                    contact_name="Home contact",
                    phone_number="111",
                ),
                EmergencyContact(
                    id=2,
                    premise_id=2,
                    contact_name="Other contact",
                    phone_number="222",
                ),
            ]
        )
        self.db.commit()

        listed = list_emergency_contacts(
            current_user={"user_id": 2},
            db=self.db,
        )

        self.assertEqual([contact.contact_name for contact in listed], ["Home contact"])
        with self.assertRaises(HTTPException) as context:
            update_emergency_contact(
                2,
                EmergencyContactUpdate(contact_name="Not allowed"),
                current_user={"user_id": 1},
                db=self.db,
            )
        self.assertEqual(context.exception.status_code, 404)

    def test_normal_user_cannot_modify_contacts(self):
        request = EmergencyContactCreate(
            contact_name="Contact",
            phone_number="123456",
        )

        with self.assertRaises(HTTPException) as context:
            create_emergency_contact(
                request,
                current_user={"user_id": 2},
                db=self.db,
            )

        self.assertEqual(context.exception.status_code, 403)

    def test_update_and_delete_contact(self):
        contact = create_emergency_contact(
            EmergencyContactCreate(
                contact_name="Guard",
                phone_number="123456",
            ),
            current_user={"user_id": 1},
            db=self.db,
        )

        updated = update_emergency_contact(
            contact.id,
            EmergencyContactUpdate(priority=4, enabled=False),
            current_user={"user_id": 1},
            db=self.db,
        )
        self.assertEqual(updated.priority, 4)
        self.assertFalse(updated.enabled)

        delete_emergency_contact(
            contact.id,
            current_user={"user_id": 1},
            db=self.db,
        )
        self.assertEqual(self.db.query(EmergencyContact).count(), 0)


if __name__ == "__main__":
    unittest.main()
