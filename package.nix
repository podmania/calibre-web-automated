{ lib
, stdenv
, fetchFromGitHub
, python3Packages
}:

python3Packages.buildPythonApplication rec {
  pname = "calibre-web-automated";
  version = "4.0.6";        # CI updates this
  pyproject = true;

  src = fetchFromGitHub {
    owner = "crocodilestick";
    repo = "Calibre-Web-Automated";
    rev = "v${version}";
    hash = "sha256-4BvExsiSv9hyeLjWuRxR+xGW7Fz2eUEJo5piRgE/ang=";              # CI replaces this
  };
  
  packages = [ "cps" ];
  packageDir = "cps";

  dependencies = with python3Packages; [
    apscheduler
    babel
    bleach
    chardet
    cryptography
    flask
    flask-babel
    flask-httpauth
    flask-limiter
    flask-principal
    flask-wtf
    iso-639
    lxml
    netifaces-plus
    pycountry
    pypdf
    python-magic
    pytz
    regex
    requests
    sqlalchemy
    tornado
    unidecode
    urllib3
    wand
  ];

  optional-dependencies = {
    comics = with python3Packages; [ comicapi natsort ];
    gdrive = with python3Packages; [ gevent google-api-python-client greenlet httplib2 oauth2client pyasn1-modules pyyaml rsa uritemplate ];
    gmail = with python3Packages; [ google-api-python-client google-auth-oauthlib ];
    kobo = with python3Packages; [ jsonschema ];
    ldap = with python3Packages; [ flask-simpleldap python-ldap ];
    metadata = with python3Packages; [ faust-cchardet html2text markdown2 mutagen py7zr pycountry python-dateutil rarfile scholarly ];
    oauth = with python3Packages; [ flask-dance sqlalchemy-utils ];
  };

  pythonRelaxDeps = [
    "apscheduler" "bleach" "cryptography" "flask" "flask-limiter"
    "lxml" "pypdf" "regex" "tornado" "unidecode" "wand"
  ];

  pythonImportsCheck = [ "cps" ];

  meta = {
    description = "Calibre-Web but Automated and with tons of New Features! Fully automate and simplify your eBook set up!";
    homepage = "https://github.com/crocodilestick/Calibre-Web-Automated";
    license = lib.licenses.gpl3Plus;
    mainProgram = "cps";
    platforms = lib.platforms.linux;
  };
}
