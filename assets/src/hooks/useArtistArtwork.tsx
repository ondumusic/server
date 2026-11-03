import { useCallback, useRef, useState } from "react";
import { artistApi } from "../api/artists";
import {
  type ArtworkResult,
  isArtworkError,
  maxArtworkSize,
  maxArtworkSizeMB,
} from "../api/artwork";
import i18next from "../i18next";
import { sync } from "../library/sync";
import type { Artist, UUID } from "../types";
import { artworkUrl } from "../utils/artwork";
import type { ContextMenuItem } from "./useContextMenu";
import { useDialog } from "./useDialog";
import { useToast } from "./useToast";

function errorMessage(error?: string) {
  switch (error) {
    case "invalid_image":
      return i18next.t("artistArtwork.error.invalidImage", {
        defaultValue: "That file is not a valid image.",
      });
    case "too_large":
      return i18next.t("artistArtwork.error.tooLarge", {
        defaultValue:
          "The image is too large, it can be at most {{ maxSize }}MB.",
        maxSize: maxArtworkSizeMB,
      });
    default:
      return i18next.t("artistArtwork.error.failed", {
        defaultValue: "Failed to update the artwork, please try again.",
      });
  }
}

export function useArtistArtwork() {
  const { showToast } = useToast();
  const { showAlert, promptConfirm } = useDialog();
  const [updatingArtistId, setUpdatingArtistId] = useState<UUID | null>(null);
  const inputRef = useRef<HTMLInputElement | null>(null);

  const showError = useCallback(
    (error?: string) => {
      showAlert({
        message: errorMessage(error),
        confirmMessage: i18next.t("artistArtwork.error.ok", {
          defaultValue: "OK",
        }),
      });
    },
    [showAlert],
  );

  const applyArtwork = useCallback(
    async (
      artist: Artist,
      request: () => Promise<ArtworkResult<Artist>>,
      toastMessage: string,
    ) => {
      setUpdatingArtistId(artist.id);
      try {
        const updatedArtist = await request();
        if (isArtworkError(updatedArtist)) {
          showError(updatedArtist.error);
          return;
        }

        await sync.pushChanges({ artists: [updatedArtist] });
        showToast({ message: toastMessage });
      } catch {
        showError();
      } finally {
        setUpdatingArtistId(null);
      }
    },
    [showError, showToast],
  );

  const uploadArtwork = useCallback(
    async (artist: Artist, file: File) => {
      if (!file.type.startsWith("image/")) {
        showError("invalid_image");
        return;
      }

      if (file.size > maxArtworkSize) {
        showError("too_large");
        return;
      }

      await applyArtwork(
        artist,
        () => artistApi.putArtwork(artist.id, file),
        i18next.t("toast.artistArtworkUpdated", {
          defaultValue: "Updated the artwork for {{ artistName }}",
          artistName: artist.name,
        }),
      );
    },
    [showError, applyArtwork],
  );

  const chooseArtwork = useCallback(
    (artist: Artist) => {
      const input = document.createElement("input");
      input.type = "file";
      input.accept = "image/*";
      input.onchange = () => {
        inputRef.current = null;
        const file = input.files?.[0];
        if (file) uploadArtwork(artist, file);
      };
      inputRef.current = input;
      input.click();
    },
    [uploadArtwork],
  );

  const removeArtwork = useCallback(
    async (artist: Artist) => {
      const confirmed = await promptConfirm({
        danger: true,
        message: i18next.t("promptRemoveArtistArtwork.message", {
          defaultValue: "Remove the artwork from {{ artistName }}?",
          artistName: artist.name,
        }),
        confirmMessage: i18next.t("promptRemoveArtistArtwork.confirm", {
          defaultValue: "Remove",
        }),
        cancelMessage: i18next.t("promptRemoveArtistArtwork.cancel", {
          defaultValue: "Cancel",
        }),
      });
      if (!confirmed) return;

      await applyArtwork(
        artist,
        () => artistApi.deleteArtwork(artist.id),
        i18next.t("toast.artistArtworkRemoved", {
          defaultValue: "Removed the artwork from {{ artistName }}",
          artistName: artist.name,
        }),
      );
    },
    [promptConfirm, applyArtwork],
  );

  const contextMenuItems = useCallback(
    (artist: Artist): ContextMenuItem[] => {
      if (!artworkUrl(artist)) {
        return [
          {
            type: "item",
            key: "add_artwork",
            label: i18next.t("contextMenu.addArtistArtwork", {
              defaultValue: "Choose Artwork...",
            }),
            onClick: () => chooseArtwork(artist),
          },
        ];
      }

      return [
        {
          type: "item",
          key: "replace_artwork",
          label: i18next.t("contextMenu.replaceArtistArtwork", {
            defaultValue: "Replace Artwork...",
          }),
          onClick: () => chooseArtwork(artist),
        },
        {
          type: "item",
          key: "remove_artwork",
          danger: true,
          label: i18next.t("contextMenu.removeArtistArtwork", {
            defaultValue: "Remove Artwork",
          }),
          onClick: () => removeArtwork(artist),
        },
      ];
    },
    [chooseArtwork, removeArtwork],
  );

  return { contextMenuItems, uploadArtwork, updatingArtistId };
}
