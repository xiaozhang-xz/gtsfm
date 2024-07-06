"""Generate image pairs for the frontend

Authors: Ayush Baid
"""

import os
from pathlib import Path
from typing import List, Optional, Tuple

import numpy as np
from dask.distributed import Client, Future

from gtsfm.common.image import Image
from gtsfm.frontend.global_descriptor.global_descriptor_base import GlobalDescriptorBase
from gtsfm.retriever.retriever_base import RetrieverBase


class ImagePairsGenerator:

    def __init__(self,
                 retriever: RetrieverBase,
                 global_descriptor: Optional[GlobalDescriptorBase] = None):
        self._global_descriptor: Optional[
            GlobalDescriptorBase] = global_descriptor
        self._retriever: RetrieverBase = retriever

    def __repr__(self) -> str:
        return f"""
            ImagePairGenerator:
                {self._global_descriptor}
                {self._retriever}
        """

    def generate_image_pairs(
            self,
            client: Client,
            images: List[Future],
            image_fnames: List[str],
            plots_output_dir: Optional[Path] = None,
            dataset_root: str = None) -> List[Tuple[int, int]]:

        def apply_global_descriptor(global_descriptor: GlobalDescriptorBase,
                                    image: Image) -> np.ndarray:
            return global_descriptor.describe(image=image)

        descriptors: Optional[List[np.ndarray]] = None
        if self._global_descriptor is not None:
            if self._global_descriptor.batch_process:
                full_image_fnames = [
                    os.path.join(dataset_root, 'images', i)
                    for i in image_fnames
                ]
                descriptors = list(
                    self._global_descriptor.describe(full_image_fnames))
            else:
                print('get image descriptor one by one')
                global_descriptor_future = client.scatter(
                    self._global_descriptor, broadcast=False)

                descriptor_futures = [
                    client.submit(apply_global_descriptor,
                                  global_descriptor_future, image)
                    for image in images
                ]

                descriptors = client.gather(descriptor_futures)

        return self._retriever.get_image_pairs(
            global_descriptors=descriptors,
            image_fnames=image_fnames,
            plots_output_dir=plots_output_dir)
