"""A dummy rotation averaging class which is used for testing.

Authors: Ayush Baid
"""
from typing import Dict, List, Optional, Tuple

import numpy as np
from gtsam import Rot3

from averaging.rotation.rotation_averaging_base import RotationAveragingBase


class DummyRotationAveraging(RotationAveragingBase):
    """Assigns random rotation matrices to each pose."""

    def run(self,
            num_images: int,
            i2Ri1_dict: Dict[Tuple[int, int], Optional[Rot3]]
            ) -> List[Optional[Rot3]]:
        """Run the rotation averaging.

        Args:
            num_images: number of poses.
            i2Ri1_dict: relative rotations as dictionaries where keys (i2, i1)
                        are pose pairs.

        Returns:
            Global rotations for each camera pose, i.e. w_R_i, as a list. The
                number of entries in the list is `num_images`. The list may
                contain `None` where the global rotation could not be computed
                (either underconstrained system or ill-constrained system).
        """
        if len(i2Ri1_dict) == 0:
            return [None]*num_images

        # create the random seed using relative rotations
        seed_rotation = next(iter(i2Ri1_dict.values()))

        np.random.seed(
            int(1000*seed_rotation.xyz()[0]) % (2 ^ 32))

        # TODO: do not assign values where we do not have any edge

        # generate dummy rotations
        wRi_list = []
        for _ in range(num_images):
            random_vector = np.random.rand(3)*2*np.pi
            wRi_list.append(Rot3.Rodrigues(
                random_vector[0], random_vector[1], random_vector[2]))

        return wRi_list
