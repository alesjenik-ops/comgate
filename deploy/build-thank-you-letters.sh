#!/usr/bin/env bash
# Sestavi ZIPy pro nasazeni pres Workbench (Migration > Deploy).
#
# Jediny zdroj pravdy je src-comgate-npc/ - tenhle skript z nej vytahne soubory
# podle manifestu v deploy/*/package.xml a zabali je.
#
# Deploy je zamerne rozdeleny na tri nezavisle kroky:
#   1) deploy/thank-you-letters-1-folder.zip    jen slozka DKD_Dekovne_Dopisy
#   2) deploy/thank-you-letters-2-templates.zip e-mailove sablony
#   3) deploy/thank-you-letters-3-base.zip      kod, pole, flow, komponenty, fotky
#
# Proc tri: slozka a jeji sablony nesmi jit najednou, protoze Metadata API nezarucuje
# poradi a sablony se zpracuji driv ("Cannot find folder:DKD_Dekovne_Dopisy"). A slozka nesmi
# byt ve stejnem balicku jako flow - pri Rollback On Error by ji kazda chyba flow smazala
# zpatky a krok se sablonami by spadl znovu.
#
# Pouziti:  ./deploy/build-thank-you-letters.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$REPO_ROOT/src-comgate-npc"

STAGE=""
copy() {
    # copy <relativni cesta v src-comgate-npc>
    local rel="$1"
    if [[ ! -e "$SRC/$rel" ]]; then
        echo "CHYBI: src-comgate-npc/$rel" >&2
        exit 1
    fi
    mkdir -p "$STAGE/$(dirname "$rel")"
    cp -R "$SRC/$rel" "$STAGE/$rel"
}

# ---------- krok 1: jen slozka ----------
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

cp "$REPO_ROOT/deploy/thank-you-letters-folder/package.xml" "$STAGE/package.xml"
copy email/DKD_Dekovne_Dopisy-meta.xml

ZIP1="$REPO_ROOT/deploy/thank-you-letters-1-folder.zip"
rm -f "$ZIP1"
(cd "$STAGE" && zip -qr "$ZIP1" .)
rm -rf "$STAGE"

# ---------- krok 2: sablony ----------
STAGE="$(mktemp -d)"

cp "$REPO_ROOT/deploy/thank-you-letters-templates/package.xml" "$STAGE/package.xml"
copy email/DKD_Dekovne_Dopisy

ZIP2="$REPO_ROOT/deploy/thank-you-letters-2-templates.zip"
rm -f "$ZIP2"
(cd "$STAGE" && zip -qr "$ZIP2" .)
rm -rf "$STAGE"

# ---------- krok 3: zbytek ----------
STAGE="$(mktemp -d)"

cp "$REPO_ROOT/deploy/thank-you-letters/package.xml" "$STAGE/package.xml"

# ApexClass - upraveny DonationPageController (bezpecny fallback vychoziho bankovniho uctu)
copy classes/DonationPageController.cls
copy classes/DonationPageController.cls-meta.xml
copy classes/DonationPageControllerTest.cls
copy classes/DonationPageControllerTest.cls-meta.xml

# Aura - thankYouPageUrl na formulari, cache-buster u fotky v zahlavi
copy aura/DonationPageForm
copy aura/DonationPageHeader

# LWC - thankYouPageUrl i ve verzi donationPageCommunity
copy lwc/donationPageCommunity

# Objekty - nova pole Thank_You_*
copy objects/GiftTransaction.object
copy objects/GiftCommitment.object

# Flow, ktery dopisy rozesila
copy flows/Gift_Transaction_Thank_You_Email.flow

# Vymenene fotky
copy staticresources/DonationPageHeaderImage.resource
copy staticresources/DonationPageHeaderImage.resource-meta.xml
copy staticresources/DonationPageCampaignPhoto.resource
copy staticresources/DonationPageCampaignPhoto.resource-meta.xml

ZIP3="$REPO_ROOT/deploy/thank-you-letters-3-base.zip"
rm -f "$ZIP3"
(cd "$STAGE" && zip -qr "$ZIP3" .)

echo "Hotovo - nasazujte v tomhle poradi:"
for z in "$ZIP1" "$ZIP2" "$ZIP3"; do
    printf '  %-45s %s souboru\n' "${z#"$REPO_ROOT"/}" "$(unzip -l "$z" | tail -1 | awk '{print $2}')"
done
