#!/usr/bin/env bash
# Sestavi ZIPy pro nasazeni pres Workbench (Migration > Deploy).
#
# Jediny zdroj pravdy je src-comgate-npc/ - tenhle skript z nej vytahne soubory
# podle manifestu v deploy/*/package.xml a zabali je.
#
# Deploy je zamerne rozdeleny na dva kroky:
#   1) deploy/thank-you-letters-1-base.zip      vse vcetne slozky DKD_Thank_You
#   2) deploy/thank-you-letters-2-templates.zip samotne e-mailove sablony
# Slozka a jeji sablony nesmi jit najednou - Metadata API nezarucuje poradi
# a sablony se zpracuji driv nez slozka ("Cannot find folder:DKD_Thank_You").
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

# ---------- krok 1: vse krome sablon ----------
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

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

# Slozka na dekovne dopisy (sablony az v kroku 2)
copy email/DKD_Thank_You-meta.xml

# Flow, ktery dopisy rozesila
copy flows/Gift_Transaction_Thank_You_Email.flow

# Vymenene fotky
copy staticresources/DonationPageHeaderImage.resource
copy staticresources/DonationPageHeaderImage.resource-meta.xml
copy staticresources/DonationPageCampaignPhoto.resource
copy staticresources/DonationPageCampaignPhoto.resource-meta.xml

ZIP1="$REPO_ROOT/deploy/thank-you-letters-1-base.zip"
rm -f "$ZIP1"
(cd "$STAGE" && zip -qr "$ZIP1" .)
rm -rf "$STAGE"

# ---------- krok 2: samotne sablony ----------
STAGE="$(mktemp -d)"

cp "$REPO_ROOT/deploy/thank-you-letters-templates/package.xml" "$STAGE/package.xml"
copy email/DKD_Thank_You

ZIP2="$REPO_ROOT/deploy/thank-you-letters-2-templates.zip"
rm -f "$ZIP2"
(cd "$STAGE" && zip -qr "$ZIP2" .)

echo "Hotovo:"
echo "  1) ${ZIP1#"$REPO_ROOT"/}"
unzip -l "$ZIP1" | tail -3
echo "  2) ${ZIP2#"$REPO_ROOT"/}"
unzip -l "$ZIP2"
