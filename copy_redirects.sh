#!/bin/bash

# Garante que a pasta de build existe
if [ -d "build/web" ]; then
  echo "Copiando arquivo _redirects para build/web..."
  cp web/_redirects build/web/
  echo "Arquivo copiado com sucesso! ✅"
else
  echo "Pasta build/web não encontrada. Rode 'flutter build web' antes deste script. ⚠️"
fi
