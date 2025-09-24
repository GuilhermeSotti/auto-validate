from setuptools import setup, find_packages

setup(
    name="bot_cab",
    version="1.0.0",
    packages=find_packages(),
    entry_points={
        "console_scripts": [
            "bot_cab=bot_cab.main:main"
        ]
    },
    install_requires=[
       "requests",
       "azure-identity",
       "python-dateutil"
    ],
)