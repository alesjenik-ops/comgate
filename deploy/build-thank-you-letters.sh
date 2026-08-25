#!/usr/bin/env bash
# Sestavi ZIP pro nasazeni pres Workbench (Migration > Deploy).
#
# Jediny zdroj pravdy je src-comgate-npc/ - tenhle skript z nej vytahne prave ty
# soubory, ktere jsou uvedene v deploy/thank-you-letters/package.xml, a zabali je.
# Vysledek: deploy/thank-you-letters.zip (package.xml v korenu ZIPu).
#
# Pouziti:  ./deploy/build-thank-you-letters.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$REPO_ROOT/src-comgate-npc"
MANIFEST="$REPO_ROOT/deploy/thank-you-letters/package.xml"
OUT_ZIP="$REPO_ROOT/deploy/thank-you-letters.zip"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

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

cp "$MANIFEST" "$STAGE/package.xml"

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

# E-mailove sablony dekovnych dopisu
copy email/DKD_Thank_You-meta.xml
copy email/DKD_Thank_You

# Flow, ktery dopisy rozesila
copy flows/Gift_Transaction_Thank_You_Email.flow

# Vymenene fotky
copy staticresources/DonationPageHeaderImage.resource
copy staticresources/DonationPageHeaderImage.resource-meta.xml
copy staticresources/DonationPageCampaignPhoto.resource
copy staticresources/DonationPageCampaignPhoto.resource-meta.xml

rm -f "$OUT_ZIP"
(cd "$STAGE" && zip -qr "$OUT_ZIP" .)

echo "Hotovo: ${OUT_ZIP#"$REPO_ROOT"/}"
unzip -l "$OUT_ZIP"
