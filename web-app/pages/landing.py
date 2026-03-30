"""Authenticated landing page with a premium split chat workspace."""

import streamlit as st

st.set_page_config(
    page_title="IBM Verify — Home",
    page_icon="🔷",
    layout="wide",
    initial_sidebar_state="collapsed",
)

from config import log_loaded_configuration
from observability import bind_request_context, get_logger

bind_request_context(st.session_state, st.context.headers, st.context.url)
LOGGER = get_logger("pages.landing")
log_loaded_configuration()

from auth.session import inject_theme, require_auth, get_user_info
from components.chat_workspace import render_chat_workspace
from components.navbar import render_navbar

require_auth()
inject_theme()

LOGGER.info("Rendering landing page")
render_navbar()

user_info = get_user_info()
first_name = user_info.get("name", "").split()[0] if user_info.get("name") else "there"
st.markdown(
    f"""
    <div class="premium-welcome">
        <span class="premium-welcome__label">Operator session</span>
        <span class="premium-welcome__value">Welcome, {first_name}.</span>
    </div>
    """,
    unsafe_allow_html=True,
)

render_chat_workspace()
